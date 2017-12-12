defmodule User do
    use GenServer
    require Logger
    # alias Phoenix.Channels.GenSocketClient
    # @behaviour GenSocketClient






    # def handle_info({:send_tweet, userID, tweet}, transport, state) do
    #     GenSocketClient.push(transport, "tweeter:send_tweet", "send_tweet", %{tweet: tweet, userID: userID})
    #     {:ok, state}
    # end
    # def handle_info({:re_tweet, userID, tweet}, transport, state) do
    #     GenSocketClient.push(transport, "tweeter:re_tweet", "re_tweet", %{tweet: tweet, userID: userID})
    #     {:ok, state}
    # end

    # def handle_info({:subscribe, userID, to_followID}, transport, state) do
    #     GenSocketClient.push(transport, "tweeter:subscribe", "subscribe", %{userID: userID, to_followID: to_followID})
    #     {:ok, state}
    # end

    # def handle_info({:query_tweet, query}, transport, state) do
    #     GenSocketClient.push(transport,"tweeter:query", "query", %{query: query})
    #     {:ok, state}
    # end

    # def handle_info(message, transport, state) do
    #     Logger.warn("Unhandled message #{inspect message}")
    #     {:ok, state}
    # end
    def start_link(userID) do
        {:ok, user} = GenServer.start_link(__MODULE__, [], name: via_tuple(userID))
        IO.puts "user is started with pid:"
        IO.inspect user
    end

    defp via_tuple(userID) do
        {:via, :gproc, {:n, :l, {:userPool, userID}}}
    end

    def register_account(workerID, userID) do
        GenServer.call(via_tuple(workerID), {:register_account, userID}, :infinity)
    end


    def init([]) do
        state = %{userID: "", connected: false, followers: [], followings: [], tweets: []}   
        #new_state = %{state | userID: userID}
        {:ok, state}  
    end

    @doc """
    Connection API should return status = {userID, connection_status, followers, followings, tweets}
    The first time it is connected, followers, followings, tweets are []
    """
    def handle_call({:register_account, userID}, _from, state) do
        # register_status = Server.register_account(userID)
        IO.puts "Sending msg to websocket..."
        # Process.send_after(userID<>"socket", {:register_account, userID}, :timer.seconds(1) )
        {:reply, state, state}
    end

    ######################### callbacks ####################

#     def handle_cast({:send_tweet, tweet}, state) do
#         Server.send_tweet(tweet, state[:userID])
#         tweets = [tweet | state[:tweets]]      
#         new_state = %{state | tweets: tweets}        
#         {:noreply, new_state}        
#     end


#     def handle_cast({:re_tweet, tweet}, state) do
#         Server.re_tweet(tweet, state[:userID])
#         tweets = [tweet | state[:tweets]]      
#         new_state = %{state | tweets: tweets}        
#         {:noreply, new_state}        
#     end

#     @doc """
#     Only add a new follower if the user successfully subscribes to it, i.e., the server returns :ok
#     """
#     def handle_call({:subscribe, userID, to_followID}, _from, state) do
#         subscribe_status = Server.subscribe(to_followID, userID)
#         case subscribe_status do
#             :ok -> 
#                 followers = state[:followers]
#                 follower_list = [to_followID | followers]
#                 new_state = %{state | followers: follower_list}
#             :error ->
#                 error_info = "Failed to subscribe to " <> to_followID
#                 IO.puts error_info
#         end

#         {:reply, subscribe_status, state}
#     end

#     def handle_call({:query_tweet, query}, _from, state) do
#         query_result = Server.query_tweet(query, state[:userID])
#         print_tweets(state[:userID], query_result)
#         {:reply, query_result, state} 
#     end

#     @doc """
#     Once the user is connected, the server returns the user's tweets (including 
#     the user's own tweets and his/her followers' tweets) and those tweets that mentions
#     this user.
#     time_line is a tuple {[tweets], [mentions]}
#     """
#     def handle_call({:connect}, _from, state) do
#         time_line = Server.connect(state[:userID])
#         print_timeline(state[:userID], time_line)
#         new_state = %{state | tweets: elem(time_line, 0)}        
#         {:reply, :ok, new_state}
#     end

#     ######################### helper functions ####################
#     @doc """
#     The query result does not distinguish btw the 3 types. So 
#     case1: query subscription, the result would be all the tweets on the user's timeline. 
#     case2: query hashtag, the result would be all the tweets under this topic, i.e., marked with this hashtag.
#     case3: query mention, the result would be all the tweets that mentions this user.
#     """
#     defp print_tweets(userID, tweets) do
#         IO.puts "User: #{userID}'s query result is:"
#         case length(tweets) do
#             0 -> 
#                 IO.puts "Oops, there is no matched tweet!"
#             _ ->
#                 Enum.each(tweets, fn(tweet) -> 
#                     IO.puts tweet
#                 end)
#         end
#     end

#     defp print_timeline(userID, time_line) do
#         IO.puts "\nUser: #{userID}'s timeline is:"
#         tweets = elem(time_line, 0) # all tweets that this user subscribed
#         mentions = elem(time_line, 1) # all the tweets that mentions this user
#         cond do
#             length(tweets) == 0 && length(mentions) == 0 ->
#                 IO.puts "Oops, your timeline is blank!"
#             length(tweets) == 0 ->
#                 IO.puts "~~~~~~Tweets that mentions you:~~~~~~"
#                 Enum.each(mentions, fn(mention) -> 
#                     # mention is a tuple {"shanfang", "Are you working on the project @shanfang?"}
#                     IO.puts elem(mention, 1) 
#                 end)
#             length(mentions) == 0 ->
#                 IO.puts "~~~~~~Tweets from your subscription:~~~~~~"                                
#                 Enum.each(tweets, fn(tweet) -> 
#                     IO.puts tweet
#                 end)
#             true ->
#                 IO.puts "~~~~~~Tweets from your subscription:~~~~~~"                
#                 Enum.each(tweets, fn(tweet) -> 
#                     IO.puts tweet
#                 end)

#                 IO.puts "\n~~~~~~Tweets that mentions you:~~~~~~"                
#                 Enum.each(mentions, fn(mention) -> 
#                     IO.puts elem(mention, 1) 
#                 end)
#         end
#     end
end