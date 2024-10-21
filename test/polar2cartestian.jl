using Pkg
Pkg.activate(".")

using CadCAD: run_exp
using Catlab
using Catlab.Theories
using Catlab.CategoricalAlgebra

# Define custom space types
@acset_type CartesianSpace(Spaces.AbstractSpace) begin
    x::Float64
    y::Float64
end

@acset_type PolarSpace(Spaces.AbstractSpace) begin
    r::Float64
    phi::Float64
end

# Helper functions to create spaces
function create_cartesian_space(x::Float64, y::Float64)
    s = CartesianSpace()
    add_part!(s, :Point)
    add_part!(s, :Space)
    set_subpart!(s, :element, 1, 1)
    set_subpart!(s, :x, 1, x)
    set_subpart!(s, :y, 1, y)
    return s
end

function create_polar_space(r::Float64, phi::Float64)
    s = PolarSpace()
    add_part!(s, :Point)
    add_part!(s, :Space)
    set_subpart!(s, :element, 1, 1)
    set_subpart!(s, :r, 1, r)
    set_subpart!(s, :phi, 1, phi)
    return s
end

# Define dynamics functions
function cartesian2polar(cart::CartesianSpace)
    x = get_subpart(cart, :x, 1)
    y = get_subpart(cart, :y, 1)
    r = sqrt(x^2 + y^2)
    phi = atan(y, x)
    return create_polar_space(r, phi)
end

function polar2cartesian(pol::PolarSpace)
    r = get_subpart(pol, :r, 1)
    phi = get_subpart(pol, :phi, 1)
    x = r * cos(phi)
    y = r * sin(phi)
    return create_cartesian_space(x, y)
end

# Set the parameters
sim_params = (
    n_steps = 5,
    n_runs = 1
)

# Set the initial state
initial_state = create_cartesian_space(1.5, 3.7)

# Define the dynamics function
function dynamics_func(state)
    if state isa CartesianSpace
        return cartesian2polar(state)
    elseif state isa PolarSpace
        return polar2cartesian(state)
    else
        error("Unknown state type")
    end
end

# Run the simulation
trajectory = CadCAD.run_exp(initial_state, sim_params, dynamics_func)

# Print the results
for (run, states) in enumerate(trajectory)
    println("Run $run:")
    for (step, state) in enumerate(states)
        if state isa CartesianSpace
            x = get_subpart(state, :x, 1)
            y = get_subpart(state, :y, 1)
            println("  Step $step: Cartesian(x=$x, y=$y)")
        elseif state isa PolarSpace
            r = get_subpart(state, :r, 1)
            phi = get_subpart(state, :phi, 1)
            println("  Step $step: Polar(r=$r, phi=$phi)")
        end
    end
    println()
end