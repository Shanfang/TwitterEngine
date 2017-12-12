defmodule App do
    @doc """
    This application accept number of clients and serverID as input, use this to set up a simulator.
    The simulator simulates clients sending tweets and receiving tweets.
    """
    def main(args) do
        num_of_clients = Enum.at(args, 0) |> String.to_integer
        following_num = Enum.at(args, 1) |> String.to_integer
        limit = Enum.at(args, 2) |> String.to_integer
        loop(num_of_clients, following_num, limit, 1)
    end

    def loop(num_of_clients, following_num, limit, n) when n > 0 do              
        Enum.each(1..num_of_clients, fn(user) ->
            user |> Integer.to_string |> SocketClient.start_link(following_num, limit)
        end)
        loop(num_of_clients, following_num, limit, n - 1)
    end

    def loop(num_of_clients, following_num,limit, n) do
        :timer.sleep 1000
        loop(num_of_clients, following_num, limit, n)
    end
end
