# WiP

module Polar2Cartesian

using CadCAD: Point, run_exp
import Base: show

# Create the spaces as kwdef structs (for now)

@kwdef struct Cartesian <: Point
    x::Float64
    y::Float64
end

@kwdef struct Polar <: Point
    r::Float64
    phi::Float64
end

# Add custom show methods
function show(io::IO, cart::Cartesian)
    print(io, "Cartesian(x=$(cart.x), y=$(cart.y))")
end

function show(io::IO, pol::Polar)
    print(io, "Polar(r=$(pol.r), phi=$(pol.phi))")
end

# Set the parameters

sim_params = (
    n_steps = 5,
    n_runs = 1
)

# Define the dynamics of the simulation

function cartesian2polar(cart::Cartesian)::Polar
    return Polar(
        sqrt(cart.x^2 + cart.y^2),
        atan(cart.y, cart.x)
    )
end

function polar2cartesian(pol::Polar)::Cartesian
    return Cartesian(
        pol.r * cos(pol.phi),
        pol.r * sin(pol.phi)
    )
end

# Set the initial state

initial_conditions = Cartesian(1.5, 3.7)

# Set the pipeline

pipeline = "cartesian2polar > polar2cartesian"

# Define the function dictionary
func_dict = Dict(
    "cartesian2polar" => cartesian2polar,
    "polar2cartesian" => polar2cartesian
)

# Run the simulation with the function dictionary
trajectory = run_exp(initial_conditions, sim_params, pipeline, func_dict)

# Print the results
for (run, states) in enumerate(trajectory)
    println("Run $run:")
    for (step, state) in enumerate(states)
        println("  Step $step: $state")
    end
    println()
end

end
