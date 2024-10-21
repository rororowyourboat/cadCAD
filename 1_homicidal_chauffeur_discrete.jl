using Plots

# Define types
struct PursuerState
    x::Float64
    y::Float64
    θ::Float64
end

struct EvaderState
    x::Float64
    y::Float64
end

struct PursuerControl
    φ::Float64
end

struct EvaderControl
    vx::Float64
    vy::Float64
end

# Constants
Δt = 0.1
const v_p = 1.0
const L = 0.5
const v_e_max = 0.5
const max_steering_angle = π / 4

# Update functions
function pursuer_update(p_state::PursuerState, p_control::PursuerControl)
    x_p_new = p_state.x + Δt * v_p * cos(p_state.θ)
    y_p_new = p_state.y + Δt * v_p * sin(p_state.θ)
    θ_p_new = p_state.θ + Δt * (v_p / L) * tan(p_control.φ)
    return PursuerState(x_p_new, y_p_new, θ_p_new)
end

function evader_update(e_state::EvaderState, e_control::EvaderControl)
    x_e_new = e_state.x + Δt * e_control.vx
    y_e_new = e_state.y + Δt * e_control.vy
    return EvaderState(x_e_new, y_e_new)
end

# Control strategies
function pursuer_control(p_state::PursuerState, e_state::EvaderState)
    angle_to_evader = atan(e_state.y - p_state.y, e_state.x - p_state.x)
    angle_diff = angle_to_evader - p_state.θ
    angle_diff = atan(sin(angle_diff), cos(angle_diff))
    φ = clamp(angle_diff, -max_steering_angle, max_steering_angle)
    return PursuerControl(φ)
end

function evader_control(p_state::PursuerState, e_state::EvaderState)
    dx = e_state.x - p_state.x
    dy = e_state.y - p_state.y
    distance = sqrt(dx^2 + dy^2) + 1e-6
    vx = (dx / distance) * v_e_max
    vy = (dy / distance) * v_e_max
    return EvaderControl(vx, vy)
end

function run_simulation()
    # Simulation
    p_state = PursuerState(0.0, 0.0, 0.0)
    e_state = EvaderState(5.0, 5.0)
    total_time = 20.0
    num_steps = Int(total_time / Δt)

    p_states = Vector{PursuerState}(undef, num_steps + 1)
    e_states = Vector{EvaderState}(undef, num_steps + 1)
    p_states[1] = p_state
    e_states[1] = e_state

    for k in 1:num_steps
        p_state = p_states[k]
        e_state = e_states[k]
        p_control = pursuer_control(p_state, e_state)
        e_control = evader_control(p_state, e_state)
        p_state_new = pursuer_update(p_state, p_control)
        e_state_new = evader_update(e_state, e_control)
        p_states[k + 1] = p_state_new
        e_states[k + 1] = e_state_new
    end

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
    title!("Homicidal Chauffeur Pursuit-Evasion (Discrete-Time)")
    
    # Save the plot as a PNG file
    savefig("homicidal_chauffeur_plot.png")
    
    println("Simulation completed. Plot saved as 'homicidal_chauffeur_plot.png'")
end

# Run the simulation
run_simulation()
