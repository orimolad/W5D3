require 'sqlite3'
require 'singleton'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class Question 
  attr_accessor :title, :body, :author_id
  
  def self.find_by_id(id)
    question = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        questions
      WHERE 
        id = ?
        
    SQL
    return nil unless question.length > 0
    Question.new(question.first)
  end

  def self.find_by_title(title)
    question = QuestionsDatabase.instance.execute(<<-SQL, title)
      SELECT
        *
      FROM
        questions
      WHERE 
        title = ?
        
    SQL
    return nil unless question.length > 0
    Question.new(question.first)
  end

  def self.find_by_body(body)
    question = QuestionsDatabase.instance.execute(<<-SQL, body)
      SELECT
        *
      FROM
        questions
      WHERE
        body = ?
    SQL
    return nil unless question.length > 0
    Question.new(question.first)
  end

  def self.find_by_author_id(author_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL
    return nil unless questions.length > 0
    questions.map{|question| Question.new(question)}
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def author 
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_question_id(@id)
  end

  def followers 
    QuestionFollow.followers_for_question_id(@id)
  end
end

class Reply
  attr_accessor :question_id, :body, :parent_id, :user_id

  def self.find_all
      replies = QuestionsDatabase.instance.execute(<<-SQL)
    SELECT
      *
    FROM
      replies
        
    SQL
    return nil unless replies.length > 0
   replies.map{|reply| Reply.new(reply)}

  end
  def self.find_by_id(id)
    reply = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        replies
      WHERE 
        id = ?
        
    SQL
    return nil unless reply.length > 0
    Reply.new(reply.first)
  end

  def self.find_by_user_id(user_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL
    return nil unless replies.length > 0
    replies.map { |reply| Reply.new(reply) }
  end

  def self.find_by_question_id(question_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL
    return nil unless replies.length > 0
    replies.map { |reply| Reply.new(reply) }
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @parent_id = options['parent_id']
    @user_id = options['user_id']
    @body = options['body']
  end

  def author
    User.find_by_id(@user_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_id)
  end

  def child_replies
    Reply.find_all.select {|reply| reply.parent_id == @id}
  end
end

class User
  attr_accessor :fname, :lname

  def self.find_by_name(fname, lname)
    user = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL
    return nil unless user.length > 0
    User.new(user.first)
  end

  def self.find_by_id(id)
    user = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL
    return nil unless user.length > 0
    User.new(user.first)
    
  
  end
  def initialize(options)
    @id = options["id"]
    @fname = options["fname"]
    @lname = options["lname"]
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions 
    QuestionFollow.followed_questions_for_user_id(@id)
  end
end

class QuestionFollow

  def self.followers_for_question_id(question_id)
    users = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        user_id
      FROM
        users AS u
      JOIN
        question_follows AS qf ON u.id = qf.user_id
      WHERE
        qf.question_id = ?
    SQL
    # [{user_id => 1},{user_id => 2},{user_id => 3}]
    return nil unless users.length > 0
    users.map { |user| User.find_by_id(user["user_id"]) }
  end

  #[{id => 1, fname => Ned ..}, {id => 2..}, {id => 3..}]
  def self.followed_questions_for_user_id(user_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        question_id
      FROM
        questions AS q
      JOIN
        question_follows AS qf ON q.id = qf.question_id
      WHERE
        user_id = ?
    SQL
    # [{question_id => 1},{question_id => 2},{question_id => 3}]
    return nil unless questions.length > 0
    questions.map { |question| Question.find_by_id(question["question_id"]) }
  end

  def self.most_followed_questions(n)
    questions = QuestionsDatabase.instance.execute(<<-SQL)
      SELECT
        id
      FROM
        questions
    SQL
    rankinghash = Hash.new()
    questions.each do |question| 
      rankinghash[question["id"]] = QuestionFollow.followers_for_question_id(question["id"])
    end
    rankings_sorted = [*rankinghash].sort{|a,b| p a[1]; a[1].length <=> b[1].length}
    n_rankings = rankings_sorted.reverse[0...n]
    n_rankings.map { |question| Question.find_by_id(question[0]) }
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end
end
