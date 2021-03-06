#####
##### Profile Asynchronous MCTS to figure out the optimal number of workers
#####

using AlphaZero
using ProgressMeter
using Plots

# It is important not to profile async mcts on tictactoe as the number
# of states in this game is small and so the mcts tree quickly contains
# every state.

include("../games.jl")
GAME = get(ENV, "GAME", "connect-four")
SelectedGame = GAME_MODULE[GAME]
using .SelectedGame: Game, Training

REP = 100
NUM_ITERATIONS = 256
MAX_LOG_NWORKERS = 8 # 2^8 = 256

TIME_FIG = "mcts_speed"
INFERENCE_TIME_RATIO_FIG = "inference_time_ratio"

network = Training.Network{Game}(Training.netparams)

function profile(nworkers, ngames)
  mcts = MCTS.Env{Game}(network, nworkers=nworkers, cpuct=1.)
  time = @elapsed begin
    @showprogress for i in 1:ngames
      MCTS.explore!(mcts, Game(), NUM_ITERATIONS)
    end
  end
  return time, MCTS.inference_time_ratio(mcts)
end

println("Compile everything...")
profile(1, 1)
profile(2, 1)

results = []
ts = []
itrs = []
for i in 0:MAX_LOG_NWORKERS
  nworkers = 2 ^ i
  println("Profiling MCTS with $nworkers workers...")
  time, inference_time_ratio = profile(nworkers, REP)
  push!(ts, time)
  push!(itrs, inference_time_ratio)
end

xticks = (
  collect(0:MAX_LOG_NWORKERS),
  ["$(2^i)" for i in 0:MAX_LOG_NWORKERS])

plot(0:MAX_LOG_NWORKERS, ts[1] ./ ts,
  title="Async MCTS Speedup",
  ylabel="Speedup",
  xlabel="Number of workers",
  ylims=(0, Inf),
  legend=:none,
  xticks=xticks)

hline!([1])

savefig(TIME_FIG)

plot(0:MAX_LOG_NWORKERS, 100 * itrs,
  title="Percentage of time spent in inference",
  ylims=(0, 100),
  xlabel="Number of workers",
  legend=:none,
  xticks=xticks)

savefig(INFERENCE_TIME_RATIO_FIG)
