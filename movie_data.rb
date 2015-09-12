class MovieData

  def initialize(folder = "ml-100k", set = :u)
    load_data(folder, set)
  
    @total_users = @user_database.length
    @total_movies = @movie_database.length
    @similar_users_hash = Hash.new
  end

  def load_data(folder, set)
    @database = []
    @test_database = []

    #read from u.data
    if set == :u
      movie_txt = open("#{folder.to_s}/#{set.to_s}.data")
    else
      movie_txt = open("#{folder.to_s}/#{set.to_s}.base")
      movie_txt_test = open("#{folder.to_s}/#{set.to_s}.test")
      movie_txt_test.readlines.each do |line|
        theuser,themovie,therating,thetimestamp = line.split(' ')
        @test_database.push([theuser, themovie, therating, thetimestamp])
      end     
    end

    movie_txt.readlines.each do |line|
      theuser,themovie,therating,thetimestamp = line.split(' ')
      @database.push([theuser, themovie, therating, thetimestamp])
    end
    
    #creates hashes for faster access
    @user_database = {}
    @movie_database = {}
    @database.each do |user, movie, rating, time|
      if @user_database[user] == nil
        @user_database[user] = [[movie, rating, time]]
      else
        @user_database[user].push([movie, rating, time])
      end
      
      if @movie_database[movie] == nil
        @movie_database[movie] = [[user, rating, time]]
      else
        @movie_database[movie].push([user, rating, time])
      end        
    end
  end
  
  #score out of 100
  def popularity(movie_id)
    movie_id = movie_id.to_s
    @num_reviewers = @movie_database[movie_id].length.to_f
    @score_time = 0.0
    @temp_rating = 0.0
       
    @weight_users = 0.25
    @weight_rating = 0.25
    @weight_time = 0.50
    
    @movie_database[movie_id].each do |user, rating, time|
      #divided by 2 bil so that "tim" in UNIX seconds is less than 1
      @score_time += (time.to_f / 2000000000.0)
      @temp_rating += rating.to_f
    end
  
    @score_rating = (@temp_rating / @num_reviewers) * 20.0
    @score_time = (@score_time / @num_reviewers) * 100
    @score_reviewers = (@num_reviewers / @total_users) * 100.0
    
    @final_score = ( @weight_users * @score_reviewers + @weight_rating * @score_rating + @weight_time * @score_time)
  
    return @final_score 
  end
  
  
  #this will generate a list of all movie_id’s ordered by decreasing popularity
  def popularity_list() 
    @movie_popularity = {}
    @movie_database.each do |key, val|
      @movie_popularity[key.to_i] = self.popularity(key)
    end
    
    @movie_popularity_sorted = Hash[@movie_popularity.sort_by{|k, v| v}.reverse]
  
    return @movie_popularity_sorted.keys
  end
  
  
  
  #higher numbers indicate greater similarity
  #score is out of 100, such that a user compared to itself scores 100
  def similarity(user1, user2)

    user1 = user1.to_s
    user2 = user2.to_s
  
    weight_num = 0.20
    weight_movies = 0.40
    weight_rating = 0.40
  
    user1_num_movies = @user_database[user1].length
    user2_num_movies = @user_database[user2].length
    score_num_movies = ((user1_num_movies + user2_num_movies).to_f / ([user1_num_movies, user2_num_movies].max * 2)) * 100.0 
    
    #hash consists of movieID(string) => rating(float)
    user1_hash = {}
    user2_hash = {} 
    @user_database[user1].each do |movieID, rating, time|
      user1_hash[movieID] = rating.to_f
    end
    @user_database[user2].each do |movieID, rating, time|
      user2_hash[movieID] = rating.to_f
    end  
    common_movies = user1_hash.keys & user2_hash.keys
    num_common_movies = common_movies.length
    score_common_movies = (num_common_movies / [user1_hash.keys.length, user2_hash.keys.length].max ) * 100.0
    
    rating_difference = 0
    common_movies.each do |movieID|
      rating_difference += (user1_hash[movieID] - user2_hash[movieID]).abs
    end
    
    #in case of num_common_movies being 0, then penalize the rating score by 100
    if num_common_movies == 0
      avg_rating_diff = 100  
    else
      avg_rating_diff = rating_difference / num_common_movies.to_f
    end
    
    score_rating = 100 - avg_rating_diff
   
    similarity_score = (weight_num * score_num_movies + weight_movies * score_common_movies + weight_rating * score_rating)
    
    return similarity_score
    
  end
 
  def most_similar(user)
    max_similar_users = 10
  
    user = user.to_s
    comparison_hash = {}
    @user_database.each do |other_user, vals|
      if user != other_user
        comparison_hash[other_user] = self.similarity(user, other_user) 
      end   
    end

      comparison_hash = Hash[comparison_hash.sort_by{|k, v| v}.reverse]
  
    similar_users = {}
    ctr = 1
    comparison_hash.each do |usr, val|
      if ctr > max_similar_users
        break
      end
      similar_users[usr] = val
      ctr += 1
    end

    @similar_users_hash[user] = similar_users.keys
    
    return similar_users 
  end

  def rating(user, movie)
    rating_value = 0

    if @user_database[user.to_s] != nil
      @user_database[user.to_s].each do |mov, rating, time|
        if mov == movie.to_s
          rating_value = rat
        end
      end    
    end

    return rating_value
  end

  def predict(user, movie)
    if @similar_users_hash[user] == nil
      sim_users = most_similar(user.to_s).keys
    else 
      #caching
      sim_users = @similar_users_hash[user]
    end

    rating_sum = 0.0
    rating_count = 0.0
        
    sim_users.each do |some_usr|
      @user_database[some_usr].each do |mov, rating, time|
        if mov == movie.to_s
          rating_sum += rating.to_i
          rating_count += 1
        end
      end
    end
      
    #average the scores
    prediction = 0.0
    if rating_count == 0.0
      prediction = 3.0
    else
      prediction = rating_sum / rating_count
    end

    return prediction
  end

  def movies(user)

    u_movies_data = @user_database[user.to_s]
    movies_seen = []

    u_movies_data.each do |movie, rating, time|
      movies_seen.push(movie)
    end
    
    return movies_seen
  end

  def viewers(movie)
    m_users_data = @movie_database[movie.to_s]
    users = []

    m_users_data.each do |user, rating, time|
      users.push(user)
    end
    
    return users
  end

  def run_test(k = 20000)
    test_results = Array.new

    #push to array
    if k == 20000
      @test_database.each {|line|  test_results.push( [line[0].to_i, line[1].to_i, line[2].to_i, self.predict(line[0], line[1]) ] )}
    else
      sub_array = @test_database.first(k)
      sub_array.each {|line|  test_results.push( [line[0].to_i, line[1].to_i, line[2].to_i, self.predict(line[0], line[1])] )}
    end

    results_object = MovieTest.new(test_results)

    puts "mean: #{results_object.mean}"
    puts "stddev: #{results_object.stddev}"
    puts "rms: #{results_object.rms}"
  end
  
end


class MovieTest

  def initialize(test_results)
    @test_results = test_results
  end

  def mean()
    sum = 0.0
    mean = 0
    @test_results.each {|line| sum += line[2]}

    mean = sum / @test_results.length

    return mean
  end

  def stddev()
     return Math.sqrt(self.mean)
  end

  def rms()
    sum = 0
    mean = 0

    #line[3] is the prediction, line[2] is the actual rating
    @test_results.each {|line| sum += ((line[3] - line[2]) ** 2) }
    mean = sum / @test_results.length

    rms = Math.sqrt(mean)
    return rms 
  end

  def to_a()
    return @test_results
  end

end

my_movie_data_b = MovieData.new("ml-100k", "u1")
my_movie_data_b.run_test(5000)

