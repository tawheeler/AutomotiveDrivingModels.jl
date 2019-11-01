abstract type LateralDriverModel{A} <: DriverModel{A} end

# TODO: Why does this struct live in the `lateral_driver_models.jl` file
"""
	ProportionalLaneTracker

A controller that executes the lane change decision made by the `lane change models`

# Constructors
	ProportionalLaneTracker(;σ::Float64 = NaN,kp::Float64 = 3.0,kd::Float64 = 2.0)

# Fields
- `a::Float64 = NaN` predicted acceleration
- `σ::Float64 = NaN` optional stdev on top of the model, set to zero or NaN for deterministic behavior
- `kp::Float64 = 3.0` proportional constant for lane tracking
- `kd::Float64 = 2.0` derivative constant for lane tracking
"""
mutable struct ProportionalLaneTracker <: LateralDriverModel{Float64}
    a::Float64 # predicted acceleration
    σ::Float64 # optional stdev on top of the model, set to zero or NaN for deterministic behavior
    kp::Float64 # proportional constant for lane tracking
    kd::Float64 # derivative constant for lane tracking

    function ProportionalLaneTracker(;
        σ::Float64 = NaN,
        kp::Float64 = 3.0,
        kd::Float64 = 2.0,
        )

        retval = new()
        retval.a = NaN
        retval.σ = σ
        retval.kp = kp
        retval.kd = kd
        retval
    end
end
get_name(::ProportionalLaneTracker) = "ProportionalLaneTracker"
function track_lateral!(model::ProportionalLaneTracker, laneoffset::Float64, lateral_speed::Float64)
    model.a = -laneoffset*model.kp - lateral_speed*model.kd
    model
end
function observe!(model::ProportionalLaneTracker, scene::Frame{Entity{S, D, I}}, roadway::Roadway, egoid::I) where {S, D, I}

    ego_index = findfirst(egoid, scene)
    veh_ego = scene[ego_index]
    t = veh_ego.state.posF.t # lane offset
    dt = veh_ego.state.v * sin(veh_ego.state.posF.ϕ) # rate of change of lane offset
    model.a = -t*model.kp - dt*model.kd

    model
end
function Base.rand(rng::AbstractRNG, model::ProportionalLaneTracker)
    if isnan(model.σ) || model.σ ≤ 0.0
        model.a
    else
        rand(rng, Normal(model.a, model.σ))
    end
end
function Distributions.pdf(model::ProportionalLaneTracker, a_lat::Float64)
    if isnan(model.σ) || model.σ ≤ 0.0
        Inf
    else
        pdf(Normal(model.a, model.σ), a_lat)
    end
end
function Distributions.logpdf(model::ProportionalLaneTracker, a_lat::Float64)
    if isnan(model.σ) || model.σ ≤ 0.0
        Inf
    else
        logpdf(Normal(model.a, model.σ), a_lat)
    end
end
