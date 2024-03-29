defmodule SocketClient do
    alias Phoenix.Channels.GenSocketClient
    @behaviour GenSocketClient
    
    def start_link(userID, following_num, limit) do

        {:ok, socket} = GenSocketClient.start_link(
            __MODULE__,
            Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
            {"ws://localhost:4000/socket/websocket", userID, following_num, limit}
            )
        IO.puts "socket process is: #{inspect socket}"
    end

    def init({url, userID, following_num, limit}) do
        :random.seed(:os.timestamp)
        # read tweets from a file, these tweets are used by users in the simulation process
        tweet_store = "tweet_store.txt"
                        |> File.read!
                        |> String.split("\n")
        hashtag_store = "hashtag_store.txt"
                        |> File.read!
                        |> String.split("\n")
        query_store = "query_store.txt"
                        |> File.read!
                        |> String.split("\n")

        IO.puts "Set up websocket connection to #{inspect url}"
        {:connect, url, [], %{userID: userID, following_num: following_num, limit: limit, 
            tweet_store: tweet_store, hashtag_store: hashtag_store, query_store: query_store}}
    end

    def handle_connected(transport, state) do
        IO.puts ("Websocket is connected for user:#{state[:userID]}")
        GenSocketClient.join(transport, "twitter")
        {:ok, state}
    end

    def handle_disconnected(reason, state) do
        IO.puts ("Oops, socket disconnected: #{inspect reason}")
        Process.send_after(self(), :connect, :timer.seconds(1))
        {:ok, state}
    end


    def handle_joined(topic, _payload, transport, state) do
        IO.puts ("User:#{state[:userID]} joined the topic: #{topic}")
        
        GenSocketClient.push(transport, "twitter", "register_account", %{userID: state[:userID]})
        IO.puts ("Register an account with userID: #{state[:userID]}")
        
        Process.send_after(self(), {:subscribe, state[:following_num]}, :timer.seconds(1))
        
        Process.send_after(self(), {:send_tweet, state[:limit]}, :timer.seconds(1))

        Process.send_after(self(), :re_tweet, :timer.seconds(1))

        Process.send_after(self(), :query, :timer.seconds(1))

        Process.send_after(self(), :re_connect, :timer.seconds(1))

        {:ok, state}
    end

    def handle_join_error(topic, payload, _transport, state) do
        IO.puts ("Oops, join error on the topic #{topic}: #{inspect payload}")
        {:ok, state}
    end

    def handle_channel_closed(topic, payload, _transport, state) do
        IO.puts ("Oops, channel closed from the topic #{topic}: #{inspect payload}")
        Process.send_after(self(), {:join, topic}, :timer.seconds(1))
        {:ok, state}
    end

   # invoked when a message arrives from server
    def handle_message(topic, event, payload, _transport, state) do
        IO.puts("Message on topic #{topic}: #{event} #{inspect payload}")
        {:ok, state}
    end

    def handle_reply(topic, _ref, %{"response" => %{"register_account" => event, "userID" => userID, 
                    "error" => error}}, _transport, state) do
        IO.puts("Reply for user: #{userID} \tEvent: #{event}\nError message: #{inspect error}")
        {:ok, state}
    end

    def handle_reply(topic, _ref, %{"response" => %{"subscribe" => event, "userID" => userID, 
                    "error" => error}}, _transport, state) do
        IO.puts("Reply for user: #{userID} \tEvent: #{event}\nError message: #{inspect error}")
        {:ok, state}
    end

    def handle_reply(topic, _ref, %{"response" => %{"userID" => userID, 
                    "query" => query, "result" => result}}, _transport, state) do
        IO.puts("Reply for user: #{userID} \tEvent: query for #{query}")
        Enum.each(result, fn(item) -> IO.puts(item) end)
        {:ok, state}
    end

    def handle_reply(topic, _ref, %{"response" => %{"re_connect" => event, "userID" => userID, 
                    "tweets" => tweets}}, _transport, state) do
        IO.puts("Reply for user: #{userID} \tEvent: #{event}\nYour time line:")
        Enum.each(tweets, fn(tweet) -> IO.puts(tweet) end)
        {:ok, state}
    end

    def handle_info(:connect, _transport, state) do
        IO.puts ("Connecting")
        {:connect, state}
    end

    def handle_info({:join, topic}, transport, state) do
        IO.puts ("User #{state[:userID]} is joining the topic #{topic}")
        case GenSocketClient.join(transport, topic) do
            {:error, reason} ->
                IO.puts ("Error joining the topic #{topic}: #{inspect reason}")
                Process.send_after(self(), {:join, topic}, :timer.seconds(1))
            {:ok, _ref} -> IO.puts("Joined again ^_^")
        end
        {:ok, state}
    end

    def handle_info({:subscribe, following_num}, transport, state) do
        to_subscribe_IDs = Enum.take_random(1..100, following_num) 
        Enum.each(to_subscribe_IDs, fn(to_subscribe_ID) -> 
            to_subscribe_ID = Integer.to_string(to_subscribe_ID)
            IO.puts ("User:#{state[:userID]} is subscribing to User:#{to_subscribe_ID}")
            GenSocketClient.push(transport, "twitter", "subscribe", 
                            %{to_subscribe_ID: to_subscribe_ID, userID: state[:userID]})
        end)
        {:ok, state}
    end
    
    def handle_info({:send_tweet, num}, transport, state) do
        tweets = Enum.take_random(state[:tweet_store], num)
        Enum.each(tweets, fn(tweet) -> 
                IO.puts ("User #{state[:userID]} is sending tweet: #{tweet}")
                GenSocketClient.push(transport, "twitter", "send_tweet", 
                                    %{tweet: tweet, userID: state[:userID]})
        end)
        {:ok, state}
    end

    def handle_info(:re_tweet, transport, state) do
        tweet = "Hi, I am #Shanfang"
        IO.puts ("User #{state[:userID]} is retweeting: #{tweet}")
        GenSocketClient.push(transport, "twitter", "re_tweet", 
                            %{tweet: tweet, userID: state[:userID]})
        {:ok, state}
    end

    def handle_info(:query, transport, state) do
        # query = "@Shanfang"
        [query | _] = Enum.take_random(state[:query_store], 1)
        # query = "#christmas"
        IO.puts ("User #{state[:userID]} is query with: #{query}")
        GenSocketClient.push(transport, "twitter", "query", 
                            %{query: query, userID: state[:userID]})
        {:ok, state}
    end

    def handle_info(:re_connect, transport, state) do
        IO.puts ("User #{state[:userID]} is reconnecting")
        GenSocketClient.push(transport, "twitter", "re_connect", %{userID: state[:userID]})
        {:ok, state}
    end
end