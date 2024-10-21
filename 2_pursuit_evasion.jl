
using Plots

# Define Space types
abstract type Space end

# Concept Note:
# In the GDS framework, a **Space** represents a collection of dimensions or variables.
# Here, we define an abstract type `Space` to serve as the base for different spaces in our model.
# Each concrete Space corresponds to an **object** in category theory.

"""
Represents the state space of the pursuer.

Fields:
- x::Float64: x-coordinate of the pursuer
- y::Float64: y-coordinate of the pursuer
- θ::Float64: orientation angle of the pursuer
"""
struct PursuerStateSpace <: Space
    x::Float64
    y::Float64
    θ::Float64
end

# Concept Note:
# `PursuerStateSpace` is a concrete implementation of a Space.
# It represents the state variables of the pursuer agent.
# In category theory, this is an object in the category of types (T).
# In the GDS framework, this space is part of the **domain** and **codomain** of Blocks (morphisms).

"""
Represents the state space of the evader.

Fields:
- x::Float64: x-coordinate of the evader
- y::Float64: y-coordinate of the evader
"""
struct EvaderStateSpace <: Space
    x::Float64
    y::Float64
end

# Concept Note:
# Similar to `PursuerStateSpace`, `EvaderStateSpace` represents the state variables of the evader agent.

"""
Represents the control space of the pursuer.

Fields:
- φ::Float64: steering angle of the pursuer
"""
struct PursuerControlSpace <: Space
    φ::Float64
end

# Concept Note:
# `PursuerControlSpace` represents the control input space for the pursuer.
# Control spaces are also considered objects in our category.

"""
Represents the control space of the evader.

Fields:
- vx::Float64: x-component of the evader's velocity
- vy::Float64: y-component of the evader's velocity
"""
struct EvaderControlSpace <: Space
    vx::Float64
    vy::Float64
end

# Concept Note:
# `EvaderControlSpace` represents the control inputs for the evader.

"""
Represents a block in the Generalized Dynamical System.

Fields:
- domain::Type{D}: The input type(s) of the block (domain)
- codomain::Type{C}: The output type of the block (codomain)
- logic::Function: The function that defines the block's behavior (morphism)
"""
struct Block{D<:Tuple, C<:Space}
    domain::Type{D}
    codomain::Type{C}
    logic::Function
end

# Concept Note:
# A `Block` represents a morphism in the category theory sense.
# It maps from its **domain** (input Spaces) to its **codomain** (output Space) via some logic.
# In GDS, Blocks encapsulate the transformations (functions) between Spaces.

# Constants
const Δt = 0.1                 # Time step
const v_p = 1.0                # Pursuer speed
const L = 0.5                  # Vehicle length (affects turning radius)
const v_e_max = 0.5            # Evader maximum speed
const max_steering_angle = π/4 # Maximum steering angle constraint

# Concept Note:
# Constants define parameters of the Spaces and Blocks.
# They can be considered as part of the parameters space in GDS.

"""
Calculates the control input for the pursuer based on the current states.

Args:
- p_state::PursuerStateSpace: The current state of the pursuer
- e_state::EvaderStateSpace: The current state of the evader

Returns:
- PursuerControlSpace: The calculated control input for the pursuer
"""
function pursuer_control_logic(p_state::PursuerStateSpace, e_state::EvaderStateSpace)::PursuerControlSpace
    # Compute the angle to the evader
    angle_to_evader = atan(e_state.y - p_state.y, e_state.x - p_state.x)
    # Compute the difference between the current orientation and the angle to the evader
    angle_diff = angle_to_evader - p_state.θ
    # Normalize the angle difference to [-π, π]
    angle_diff = atan(sin(angle_diff), cos(angle_diff))
    # Apply steering angle constraints
    φ = clamp(angle_diff, -max_steering_angle, max_steering_angle)
    return PursuerControlSpace(φ)
end

# Concept Note:
# `pursuer_control_logic` defines the logic for the pursuer's control Block.
# It maps from the domain `(PursuerStateSpace, EvaderStateSpace)` to the codomain `PursuerControlSpace`.
# This function represents a morphism in the category of Blocks.

# Pursuer Control Block
pursuer_control_block = Block{Tuple{PursuerStateSpace, EvaderStateSpace}, PursuerControlSpace}(
    Tuple{PursuerStateSpace, EvaderStateSpace},  # Domain
    PursuerControlSpace,                         # Codomain
    pursuer_control_logic                        # Logic
)

# Concept Note:
# `pursuer_control_block` is an instance of a Block, representing the control strategy of the pursuer.
# It encapsulates the mapping from the pursuer's and evader's states to the pursuer's control input.

"""
Calculates the next state of the pursuer based on the current state and control input.

Args:
- p_state::PursuerStateSpace: The current state of the pursuer
- p_control::PursuerControlSpace: The control input for the pursuer

Returns:
- PursuerStateSpace: The next state of the pursuer
"""
function pursuer_dynamics_logic(p_state::PursuerStateSpace, p_control::PursuerControlSpace)::PursuerStateSpace
    # Update position based on current orientation and speed
    x_p_new = p_state.x + Δt * v_p * cos(p_state.θ)
    y_p_new = p_state.y + Δt * v_p * sin(p_state.θ)
    # Update orientation based on steering angle
    θ_p_new = p_state.θ + Δt * (v_p / L) * tan(p_control.φ)
    return PursuerStateSpace(x_p_new, y_p_new, θ_p_new)
end

# Concept Note:
# `pursuer_dynamics_logic` defines the dynamics of the pursuer.
# It represents a Block mapping from `(PursuerStateSpace, PursuerControlSpace)` to `PursuerStateSpace`.
# This Block updates the pursuer's state based on the current state and control input.

# Pursuer Dynamics Block
pursuer_dynamics_block = Block{Tuple{PursuerStateSpace, PursuerControlSpace}, PursuerStateSpace}(
    Tuple{PursuerStateSpace, PursuerControlSpace},  # Domain
    PursuerStateSpace,                              # Codomain
    pursuer_dynamics_logic                          # Logic
)

"""
Calculates the control input for the evader based on the current states.

Args:
- p_state::PursuerStateSpace: The current state of the pursuer
- e_state::EvaderStateSpace: The current state of the evader

Returns:
- EvaderControlSpace: The calculated control input for the evader
"""
function evader_control_logic(p_state::PursuerStateSpace, e_state::EvaderStateSpace)::EvaderControlSpace
    # Compute the vector away from the pursuer
    dx = e_state.x - p_state.x
    dy = e_state.y - p_state.y
    distance = sqrt(dx^2 + dy^2) + 1e-6  # Small epsilon to prevent division by zero
    # Compute the velocity components to move away from the pursuer
    vx = (dx / distance) * v_e_max
    vy = (dy / distance) * v_e_max
    return EvaderControlSpace(vx, vy)
end

# Concept Note:
# `evader_control_logic` defines the control strategy for the evader.
# It maps from `(PursuerStateSpace, EvaderStateSpace)` to `EvaderControlSpace`.
# This Block represents the evader's control input based on the current states.

# Evader Control Block
evader_control_block = Block{Tuple{PursuerStateSpace, EvaderStateSpace}, EvaderControlSpace}(
    Tuple{PursuerStateSpace, EvaderStateSpace},  # Domain
    EvaderControlSpace,                          # Codomain
    evader_control_logic                         # Logic
)

"""
Calculates the next state of the evader based on the current state and control input.

Args:
- e_state::EvaderStateSpace: The current state of the evader
- e_control::EvaderControlSpace: The control input for the evader

Returns:
- EvaderStateSpace: The next state of the evader
"""
function evader_dynamics_logic(e_state::EvaderStateSpace, e_control::EvaderControlSpace)::EvaderStateSpace
    # Update position based on velocity components
    x_e_new = e_state.x + Δt * e_control.vx
    y_e_new = e_state.y + Δt * e_control.vy
    return EvaderStateSpace(x_e_new, y_e_new)
end

# Concept Note:
# `evader_dynamics_logic` defines the dynamics of the evader.
# It maps from `(EvaderStateSpace, EvaderControlSpace)` to `EvaderStateSpace`.
# This Block updates the evader's state based on the current state and control input.

# Evader Dynamics Block
evader_dynamics_block = Block{Tuple{EvaderStateSpace, EvaderControlSpace}, EvaderStateSpace}(
    Tuple{EvaderStateSpace, EvaderControlSpace},  # Domain
    EvaderStateSpace,                             # Codomain
    evader_dynamics_logic                         # Logic
)

"""
Simulates the pursuit-evasion scenario by composing the blocks.

Args:
- blocks::Vector{Block}: The list of blocks in the system
- initial_states::Tuple{Space, Space}: The initial states of the pursuer and evader
- num_steps::Int: The number of simulation steps

Returns:
- Tuple{Vector{PursuerStateSpace}, Vector{EvaderStateSpace}}: The trajectories of the pursuer and evader
"""
function wire_blocks(blocks::Vector{Block}, initial_states::Tuple{Space, Space}, num_steps::Int)::Tuple{Vector{PursuerStateSpace}, Vector{EvaderStateSpace}}
    # Unpack initial states
    p_state = initial_states[1]
    e_state = initial_states[2]

    # Initialize storage for states
    p_states = Vector{PursuerStateSpace}(undef, num_steps + 1)
    e_states = Vector{EvaderStateSpace}(undef, num_steps + 1)
    p_states[1] = p_state
    e_states[1] = e_state

    # Simulation loop
    for k in 1:num_steps
        p_state = p_states[k]
        e_state = e_states[k]

        # Execute Blocks according to wiring
        # 1. Pursuer Control Block
        p_control = pursuer_control_block.logic(p_state, e_state)

        # 2. Pursuer Dynamics Block
        p_state_new = pursuer_dynamics_block.logic(p_state, p_control)

        # 3. Evader Control Block
        e_control = evader_control_block.logic(p_state, e_state)

        # 4. Evader Dynamics Block
        e_state_new = evader_dynamics_block.logic(e_state, e_control)

        # Store new states
        p_states[k + 1] = p_state_new
        e_states[k + 1] = e_state_new
    end

    return p_states, e_states
end

# Concept Note:
# `wire_blocks` represents the **wiring** of the Blocks in the GDS framework.
# It defines how Blocks are composed and executed.
# In category theory, this reflects the composition of morphisms.
# The function simulates the evolution of the system over discrete time steps.

# Initial States
initial_p_state = PursuerStateSpace(0.0, 0.0, 0.0)
initial_e_state = EvaderStateSpace(5.0, 5.0)

# Simulation Parameters
total_time = 20.0
num_steps = Int(total_time / Δt)

# Blocks list
blocks = [pursuer_control_block, pursuer_dynamics_block, evader_control_block, evader_dynamics_block]

# Run Simulation
p_states, e_states = wire_blocks(blocks, (initial_p_state, initial_e_state), num_steps)

# Visualization
x_p = [state.x for state in p_states]
y_p = [state.y for state in p_states]
x_e = [state.x for state in e_states]
y_e = [state.y for state in e_states]

plot(x_p, y_p, label="Pursuer Trajectory")
plot!(x_e, y_e, label="Evader Trajectory")
scatter!([x_p[1]], [y_p[1]], label="Pursuer Start", marker=:star)
scatter!([x_e[1]], [y_e[1]], label="Evader Start", marker=:star)
xlabel!("X")
ylabel!("Y")
title!("Homicidal Chauffeur Pursuit-Evasion (Discrete-Time with GDS)")

# Save the plot as a PNG file
savefig("homicidal_chauffeur_plot_gds1.png")

println("Simulation completed. Plot saved as 'homicidal_chauffeur_plot_gds1.png'")

