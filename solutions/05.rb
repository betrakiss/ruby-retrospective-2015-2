require 'digest\sha1'

class ObjectStore
  def self.init(&block)
    repository = Repository.new

    repository.instance_eval(&block) if block_given?
    repository
  end
end

class ObjectStore::Repository
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

  def initialize
    @current_branch = ObjectStore::Branch.new('master')
    @branches = [@current_branch]
  end

  def branch
    @branch_operator = @branch_operator ||
      ObjectStore::BranchManager.new(self)
  end

  def add(name, object)
    @current_branch.pending[name] = ObjectStore::Change.new(:add, object)
    success(ADD_SUCCESS % name, object)
  end

  def commit(message)
    return failure(COMMIT_ERROR) if @current_branch.pending.empty?

    object_count = @current_branch.pending.size
    data = @current_branch.empty? ? {} : @current_branch.last_commit.data.dup

    @current_branch.pending.each do |name, change|
      data[name] = change.value if change.type == :add
      data.delete(name) if change.type == :delete
    end

    commit = ObjectStore::Commit.new(message, data)
    @current_branch.commits << commit
    @current_branch.pending.clear

    success(COMMIT_SUCCESS % [message, object_count], commit)
  end

  def get(name)
    return failure(NOT_COMMITED % name) if @current_branch.empty?

    object = @current_branch.last_commit.data[name]

    return failure(NOT_COMMITED % name) if not object
    success(FOUND % name, object)
  end

  def remove(name)
    return failure(NOT_COMMITED % name) if @current_branch.empty?

    if (@current_branch.last_commit.data[name])
      @current_branch.pending[name] = ObjectStore::Change.new(:delete)
      success(PENDING_REMOVAL % name, get(name).result)
    else
      failure(NOT_COMMITED % name)
    end
  end

  def checkout(hash)
    hash_not_there = @current_branch.commits.all? { |c| c.hash != hash}
    return failure(HASH_MISSING % hash) if hash_not_there

    target = @current_branch.commits.select { |c| c.hash == hash }.first
    index = @current_branch.commits.index(target)
    @current_branch.commits = @current_branch.commits[0..index]

    success(HEAD_AT % hash, @current_branch.last_commit)
  end

  def log
    commits_none = @current_branch.empty?
    return failure(NO_COMMITS % @current_branch.name) if commits_none

    commits_string = ""
    @current_branch.commits.reverse_each do |c|
      params = [c.hash, c.date.strftime('%a %b %-d %H:%M %Y %z'), c.message]
      commits_string += COMMIT_LOG_PATTERN % params
    end

    commits_string.strip!
    success(commits_string)
  end

  def head
    commits_none = @current_branch.commits.empty?
    return failure(NO_COMMITS % @current_branch.name) if commits_none

    last = @current_branch.last_commit
    success("#{last.message}", last)
  end

  def success(message, result = nil)
    ObjectStore::Success.new(message, result)
  end

  def failure(message, result = nil)
    ObjectStore::Failure.new(message, result)
  end
end

class ObjectStore::Result
  attr_reader :message
  attr_reader :result

  def initialize(message, success, result = nil)
    @message = message
    @success = success
    @result = result
  end

  def success?
    @success
  end

  def error?
    not success?
  end
end

class ObjectStore::Failure < ObjectStore::Result
  def initialize(message, result = nil)
    super(message, false, result)
  end
end

class ObjectStore::Success < ObjectStore::Result
  def initialize(message, result = nil)
    super(message, true, result)
  end
end

class ObjectStore::Change
  attr_reader :type
  attr_reader :value

  def initialize(type, value = nil)
    @type = type
    @value = value
  end
end

class ObjectStore::Commit
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

  def objects
    @data.values
  end
end

class ObjectStore::Branch
  attr_accessor :pending
  attr_accessor :commits
  attr_reader :name

  def initialize(branch_name, commits = [])
      @pending = {}
      @objects = {}
      @commits = commits.dup
      @name = branch_name
  end

  def last_commit
    @commits.last
  end

  def empty?
    @commits.empty?
  end
end

class ObjectStore::BranchManager
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
    return failure(EXISTS % name) if repo_exists

    @repo.
      branches.
      push ObjectStore::Branch.new(name, @repo.current_branch.commits)
    success(CREATED % name)
  end

  def checkout(name)
    not_exists = @repo.branches.all? { |b| b.name != name }
    return failure(DOES_NOT_EXIST % name) if not_exists

    @repo.current_branch = @repo.branches.select { |b| b.name == name }.first
    success(SWITCHED_TO % name)
  end

  def remove(name)
    not_exists = @repo.branches.all? { |b| b.name != name }
    return failure(DOES_NOT_EXIST % name) if not_exists

    return failure(CANT_REMOVE) if @repo.current_branch.name == name

    @repo.branches.delete_if { |b| b.name == name }
    success(REMOVED % name)
  end

  def list
    branches_list = ""
    @repo.branches.sort! { |a, b| a.name <=> b.name }
    @repo.branches.each do |b|
      prefix = (b.name == @repo.current_branch.name ? '* ' : '  ' )
      branches_list += prefix + b.name + "\n"
    end

    branches_list.chomp!
    success(branches_list)
  end

  def success(message, result = nil)
    ObjectStore::Success.new(message, result)
  end

  def failure(message, result = nil)
    ObjectStore::Failure.new(message, result)
  end
end

