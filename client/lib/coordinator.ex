defmodule Coordinator do
    
    use GenServer

    ######################### client API ####################
    def start_link(num_of_clients) do
        GenServer.start_link(__MODULE__, num_of_clients, [name: :coordinator])        
    end
    
    # timeout is set to be infinity
    def simulate_register_account(coordinator) do
        GenServer.call(coordinator, {:simulate_register_account}, :infinity)
    end

    # this api is deprecated, subscription is simulated in the zipf's distribution simulation
    def simulate_subscribe(coordinator, following_num) do
        # set timeout to be very infinity because the subscription takes long time
        GenServer.call(coordinator, {:simulate_subscribe, following_num}, :infinity)
    end

    def simulate_zipf_distribution(coordinator, following_num, limit) do
        GenServer.call(coordinator, {:simulate_zipf_distribution, following_num, limit}, :infinity)
    end

    def simulate_retweet(coordinator) do
        GenServer.call(coordinator, {:simulate_retweet}, :infinity)
    end
    def simulate_query(coordinator) do
        GenServer.call(coordinator, {:simulate_query}, :infinity)
    end

    def simulate_user_connection(coordinator) do
        GenServer.call(coordinator, {:simulate_user_connection}, :infinity)
    end

    ######################### callbacks ####################
    def init(num_of_clients) do
        state = %{tweet_store: [], hashtag_store: [], user_list: [], users_num: num_of_clients}
        # :random.seed(:os.timestamp)

        # # read tweets from a file, these tweets are used by users in the simulation process
        # tweet_store = "tweet_store.txt"
        #                 |> File.read!
        #                 |> String.split("\n")
        #                 IO.puts "Finish initializing tweet store..."
        # hashtag_store = "hashtag_store.txt"
        #                 |> File.read!
        #                 |> String.split("\n")
        #                 IO.puts "Finish initializing hashtag store..."
                        
        # # start all the users
        # user_list = init_users(num_of_clients, [], 0)
        # #IO.puts "All the users are initiated..."
        # :ets.new(:following_table, [:set, :named_table, :protected])
        # :ets.new(:follower_table, [:set, :named_table, :protected])
        
        # new_state = %{state | tweet_store: tweet_store, hashtag_store: hashtag_store, user_list: user_list}
        {:ok, state}
    end

    def handle_call({:simulate_register_account}, _from, state) do
        simulate_registeration(state[:user_list])
        {:reply, :ok, state}
    end

    def handle_call({:simulate_subscribe, following_num}, _from, state) do
        IO.puts "Start simulating subscription, each user is subscribing to #{following_num} other users..."
        user_list = state[:user_list]
        simulate_subscription(user_list, following_num, state[:tweet_store])
        {:reply, :ok, state}
    end

    @doc """
    I follow the description from this link to set the constant in zipf's distribution
    http://mathworld.wolfram.com/ZipfsLaw.html
    Take the top 20% users as popular users, calculate each of their followers numbers 
    such that the distribution follows zipf's distribution(the top 20% users has 80% of all the followers).
    
    F(i) is the numnber of followers
    for user that is ranked as the ith most popular. For example,
    F(1) = 0.1 / 1 * users_num * following_num
    F(2) = 0.1 / 2 * users_num * following_num
    F(3) = 0.1 / 3 * users_num * following_num
    F(4) = 0.1 / 4 * users_num * following_num
    F(5) = 0.1 / 5 * users_num * following_num
    """
    def handle_call({:simulate_zipf_distribution, following_num, limit}, _from, state) do   
        tweetstore = state[:tweet_store]

        # return value like this {[user1, user2], [user1's follower_num, user2's follower_num]}
        tuple_of_two_list = config_popular_users(following_num, state[:users_num], state[:user_list]) 
        IO.puts "Finished configure top 20% popular users such that their number of followers follow zipf's distribution"
        # init_followers return [{user, [follower_list]}, {}, {}]
        listfollower_list = init_followers(elem(tuple_of_two_list, 0), elem(tuple_of_two_list, 1), state, [], 0)
                            |> subscribe_to_popular_user

        IO.puts "Finished subscribing to popular users"
        start_time = System.monotonic_time(:nanosecond )
        # IO.inspect start_time
        popular_user_send_tweet(elem(tuple_of_two_list, 0), tweetstore, limit)
        end_time = System.monotonic_time(:nanosecond )
        IO.puts "Each popular users finished sending #{limit} tweets"
        # IO.inspect end_time
        popular_user_num = elem(tuple_of_two_list, 0) |> length
        delta_time = end_time - start_time
        IO.inspect "Time passed is #{delta_time} nanoseconds"
        total_tweets = limit *  popular_user_num
        IO.inspect "Total tweets is #{total_tweets}"

        IO.puts "Tweets Per Second is: #{Float.ceil(total_tweets * 1000000000 / delta_time)}"
        {:reply, :ok, state}
    end   

    @doc """
    Randomly select half the users to retweet once if its tweets timeline is not empty
    """
    def handle_call({:simulate_retweet},_from, state) do
        test_user_list = Enum.take_random(state[:user_list], state[:users_num])
        tweet = get_tweets(1, state[:tweet_store]) |> List.first
        Enum.each(test_user_list, fn(user) -> 
            User.re_tweet(user, tweet)
        end)
        {:reply, :ok, state}
    end

    def handle_call({:simulate_query}, _from, state) do
        query_subscription(state[:user_list])
        query_by_hashtag(state[:user_list], state[:hashtag_store])
        query_by_mention(state[:user_list])    
        {:reply, :ok, state}
    end

    # 5 is not a magic number(this can be set by user), I use this for simplity.
    def handle_call({:simulate_user_connection}, _from, state) do
        simulate_connection(state[:user_list], 5)
        {:reply, :ok, state}        
    end

    ######################### helper functions ####################

    defp init_users(num_of_clients, user_list, num) when num < num_of_clients do
        user = num |> Integer.to_string         
        # User.start_link(user) 
        user_list = [user | user_list]
        init_users(num_of_clients, user_list, num + 1)
    end

    defp init_users(_, user_list, _) do
        user_list
    end

    defp simulate_registeration(user_list) do
        Enum.each(user_list, fn(user) ->
            SocketClient.start_link(user)
            # User.register_account(user, user)
            #register_status = User.register_account(user, user)
            #IO.puts "#{inspect user} is registered to server with status: #{ register_status}"
        end)
    end

    @doc """
    Each user randomly choose following_num users to subscribe to.
    There are three case about the randomly generated to_follow_user:
    case1: already in the following list, i.e., this is a duplicate. Generate a new one.
    case2: it is the user itself. Generate a new one.
    case3: a valid to_follow_user. In this case, there are two cases about user subscribing 
    to to_follow_user. 
        i) successful, add it the the user's following list
        ii) failure, generate another user to follow.

    After finish subscription, each user's following list should be
    updated in the ETS following_table table.
    """
    defp simulate_subscription(user_list, following_num, tweetstore) do
        total_user = length(user_list)
        Enum.each(user_list, fn(user) ->
            followings = subscribe(user, following_num, total_user, [], tweetstore, 0)
            :ets.insert(:following_table, {user, followings})                                    
        end)
    end
 
    defp subscribe(user, following_num, total_user, following_list, tweetstore, count) when count < following_num do      
        to_follow = :rand.uniform(total_user) - 1 |> Integer.to_string
        cond do
            to_follow in following_list -> 
                subscribe(user, following_num, total_user, following_list, tweetstore, count) 
            to_follow == user ->
                subscribe(user, following_num, total_user, following_list, tweetstore, count) 
            true ->
                subscribe_status = User.subscribe(user, user, to_follow) 

                case subscribe_status do
                    :ok -> 
                        # update to_follow user's follower list and upate the value in ETS table
                        follower_list = :ets.lookup(:follower_table, to_follow)
                        follower_list = [user | follower_list]
                        :ets.insert(:follower_table, {to_follow, follower_list})

                        # update user's following list
                        following_list = [to_follow | following_list]
                        subscribe(user, following_num, total_user, following_list, tweetstore, count + 1)
                        #IO.puts "#{user} is following #{to_follow}"  
                        tweet = get_tweets(1, tweetstore) |> List.first
                        User.send_tweet(user, tweet)                     
                    :error -> 
                        subscribe(user, following_num, total_user, following_list, tweetstore, count)                                        
                end 
                          
        end
    end

    defp subscribe(_, _, _, following_list,_, _) do      
        following_list
    end

    defp config_popular_users(following_num, users_num, user_list) do
        popular_user_num = users_num * 0.2 |> Float.ceil |> round
        reverse_list = 1..popular_user_num |> Enum.to_list |> Enum.reverse
        
        popular_users = Enum.take_random(user_list, popular_user_num) 
        total_followers = following_num * users_num * 0.8 |> Float.ceil |> round
        follower_num = Enum.reduce(reverse_list, [], fn(x, acc) -> 
                            [0.1 / x * total_followers |> Float.ceil |> round | acc]
                        end)

        # returns a list of tuples[{userID1, num_of_followers1}, {userID2, num_of_followers2}, {userID3, num_of_followers3}]    
        #Enum.zip(popular_users, follower_num)
        {popular_users, follower_num}
    end

    defp init_followers(popular_users, follower_num_list, state, result_tuple_list, index) when index < length(popular_users) do
        user = Enum.at(popular_users, index)
        follower_num = Enum.at(follower_num_list, index)
        
        followers = Enum.filter(state[:user_list], fn(candidate) -> candidate != user end)
                    |> Enum.take_random(follower_num)
        result_tuple_list = [{user, followers} | result_tuple_list]
        init_followers(popular_users, follower_num_list, state, result_tuple_list, index + 1)
    end
    
    defp init_followers(_, _, _, result_tuple_list, _) do
        IO.puts "Finished initiating popular users' followers"
        result_tuple_list  #return the list of tuples
    end

    defp subscribe_to_popular_user(tuple_list) do
        Enum.each(tuple_list, fn(tuple) -> # tuple is of form{popular_userID, [its followers' ID]}
            Enum.each(elem(tuple, 1), fn(follower) -> 
                User.subscribe(follower, follower, elem(tuple, 0))                
            end)
        end)   
    end

    # limit is used to test the peak number of tweets from popular users that the system can handle  
    defp popular_user_send_tweet(popular_users, tweetstore, limit) do
        Enum.each(popular_users, fn(user) ->
            get_tweets(limit, tweetstore)            
            |> Enum.each(fn(tweet) -> User.send_tweet(user, tweet) end)                                                                           
        end)   
    end
 
    # I set num default to 1 in the test, so that it would not take too long time.
    defp get_tweets(num, tweetstore) do
        #tweetstore |> Enum.shuffle |> List.first
        Enum.take_random(tweetstore, num)
    end

    defp print_popular_users(users, limit) do
        Enum.each(users, fn(user)-> 
            IO.puts "#{user} is a popular user with #{limit} followers"
        end)
    end 

    @doc """
    For the following three query types, each randomly select 1 users to simulate query operation.
    The return value is a list of tweets.
    """
    defp query_subscription(user_list) do
        test_user = Enum.random(user_list)        
        IO.puts "\nSimulating randomly selected user #{test_user} to query tweets by subscription..."        
        User.query_tweet(test_user, "")        
    end

    defp query_by_hashtag(user_list, hashtag_store) do
        test_user = Enum.random(user_list)

        # take 3 random hashtags to query
        #topics = Enum.take_random(hashtag_store, 3)
        #topic = hashtag_store |> Enum.shuffle |> List.first
        topic = Enum.random(hashtag_store)
        IO.puts "\nSimulating randomly selected user #{test_user} to query tweets with #{topic}..."        
        User.query_tweet(test_user, topic) 
    end

    defp query_by_mention(user_list) do
        test_user = Enum.random(user_list)

        mention_query = "@" <> test_user
        IO.puts "\nSimulating randomly selected user #{test_user} to query tweets with #{mention_query}..."                
        User.query_tweet(test_user, mention_query)
    end

    @doc """
    Randomly take num users and simulate user connecting to the server.
    After successfully connected, the user should get tweets without querying them.
    """
    defp simulate_connection(user_list, num) do
        Enum.take_random(user_list, 5) 
            |> Enum.each(fn(user) -> user |> User.connect end)        
    end
end