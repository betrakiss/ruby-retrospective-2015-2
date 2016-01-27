require 'digest\sha1'

class ObjectStore
  COMMIT_ERROR = 'Nothing to commit, working directory clean.'
  COMMIT_SUCCESS = "%s\n\t%d objects changed"
  ADD_SUCCESS = "Added %s to stage."
  HASH_MISSING = "Commit %s does not exist."
  PENDING_REMOVAL = "Added %s for removal."
  HEAD_AT = "HEAD is now at %s."
  NO_COMMITS = "Branch %s does not have any commits yet."
  COMMIT_LOG_PATTERN = "Commit %s\nDate: %s\n\n\t%s\n\n"
  NOT_COMMITED = "Object %s is not committed."
  FOUND = "Found object %s."

  attr_accessor :branches
  attr_accessor :current_branch

  def self.init(&block)
    return new() unless block

    me = new()
    me.instance_eval &block
    me
  end

  def initialize()
      @current_branch = Branch.new('master')
      @branches = [@current_branch]
  end

  def branch()
    @branch_operator = BranchManager.new(self) if not @branch_operator
    @branch_operator
  end

  def add(name, object)
    @current_branch.pending[name] = Change.new(:add, object)
    TrueResult.new(ADD_SUCCESS % name, object)
  end

  def commit(message)
    return FalseResult.new(COMMIT_ERROR) if @current_branch.pending.empty?

    object_count = @current_branch.pending.size
    data = @current_branch.empty? ? {} : @current_branch.last_commit.data.dup

    @current_branch.pending.each do |name, change|
      data[name] = change.value if change.type == :add
      data.delete(name) if change.type == :delete
    end

    commit = Commit.new(message, data)
    @current_branch.commits << commit
    @current_branch.pending.clear

    TrueResult.new(COMMIT_SUCCESS % [message, object_count], commit)
  end

  def get(name)
    return FalseResult.new(NOT_COMMITED % name) if @current_branch.empty?

    object = @current_branch.last_commit.data[name]

    return FalseResult.new(NOT_COMMITED % name) if not object
    TrueResult.new(FOUND % name, object)
  end

  def remove(name)
    return FalseResult.new(NOT_COMMITED % name) if @current_branch.empty?

    if (@current_branch.last_commit.data[name])
      @current_branch.pending[name] = Change.new(:delete)
      TrueResult.new(PENDING_REMOVAL % name)
    else
      FalseResult.new(NOT_COMMITED % name)
    end
  end

  def checkout(hash)
    hash_not_there = @current_branch.commits.all? { |c| c.hash != hash}
    return FalseResult.new(HASH_MISSING % hash) if hash_not_there

    target = @current_branch.commits.select { |c| c.hash == hash }.first
    index = @current_branch.commits.index(target)
    @current_branch.commits = @current_branch.commits[0..index]

    TrueResult.new(HEAD_AT % hash, @current_branch.last_commit)
  end

  def log()
    commits_none = @current_branch.empty?
    return FalseResult.new(NO_COMMITS % @current_branch.name) if commits_none

    commits_string = ""
    @current_branch.commits.reverse_each do |c|
      params = [c.hash, c.date.strftime('%a %b %-d %H:%M %Y %z'), c.message]
      commits_string += COMMIT_LOG_PATTERN % params
    end

    commits_string.strip!
    TrueResult.new(commits_string)
  end

  def head()
    commits_none = @current_branch.commits.empty?
    return FalseResult.new(NO_COMMITS % @current_branch.name) if commits_none

    last = @current_branch.last_commit
    TrueResult.new("#{last.message}", last)
  end
end

class OperationResult
  attr_reader :message
  attr_reader :result

  def initialize(message, success, result = nil)
    @message = message
    @success = success
    @result = result
  end

  def success?()
    @success
  end

  def error?()
    not success?
  end
end

class FalseResult < OperationResult
  def initialize(message, result = nil)
    super(message, false, result)
  end
end

class TrueResult < OperationResult
  def initialize(message, result = nil)
    super(message, true, result)
  end
end

class Change
  attr_reader :type
  attr_reader :value

  def initialize(type, value = nil)
    @type = type
    @value = value
  end
end

class Commit
  attr_reader :message
  attr_reader :data
  attr_reader :hash
  attr_reader :date

  def initialize(message, data)
    @message = message
    @data = data.dup
    @date = Time.now

    hash_pattern = "#{@date.strftime('%a %b %-d %H:%M %Y %z')}#{message}"
    @hash = Digest::SHA1.hexdigest hash_pattern
  end

  def objects()
    @data.values
  end
end

class Branch
  attr_accessor :pending
  attr_accessor :commits
  attr_reader :name

  def initialize(branch_name, commits = [])
      @pending = {}
      @objects = {}
      @commits = commits
      @name = branch_name
  end

  def last_commit()
    @commits.last
  end

  def empty?()
    @commits.empty?
  end
end

class BranchManager
  EXISTS = "Branch %s already exists."
  CREATED = "Created branch %s."
  DOES_NOT_EXIST = "Branch %s does not exist."
  SWITCHED_TO = "Switched to branch %s."
  REMOVED = "Removed branch %s."
  CANT_REMOVE = 'Cannot remove current branch.'


  def initialize(repo)
    @repo = repo
  end

  def create(name)
    repo_exists = @repo.branches.any? { |b| b.name == name }
    return FalseResult.new(EXISTS % name) if repo_exists

    @repo.branches << Branch.new(name, @repo.current_branch.commits)
    TrueResult.new(CREATED % name)
  end

  def checkout(name)
    not_exists = @repo.branches.all? { |b| b.name != name }
    return FalseResult.new(DOES_NOT_EXIST % name) if not_exists

    @repo.current_branch = @repo.branches.select { |b| b.name == name }.first
    TrueResult.new(SWITCHED_TO % name)
  end

  def remove(name)
    not_exists = @repo.branches.all? { |b| b.name != name }
    return FalseResult.new(DOES_NOT_EXIST % name) if not_exists

    return FalseResult.new(CANT_REMOVE) if @repo.current_branch.name == name

    @repo.branches.delete_if { |b| b.name == name }
    TrueResult.new(REMOVED % name)
  end

  def list()
    branches_list = ""
    @repo.branches.sort! { |a, b| a.name <=> b.name }
    @repo.branches.each do |b|
      prefix = (b.name == @repo.current_branch.name ? '* ' : '  ' )
      branches_list += prefix + b.name + "\n"
    end

    branches_list.chomp!
    TrueResult.new(branches_list)
  end
end
