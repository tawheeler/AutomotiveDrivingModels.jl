# define features traits

# most general feature(roadway, scenes, actions, vehid)
abstract type AbstractFeature end

# feature(roadway, veh)
struct EntityFeature <: AbstractFeature end
# feature(roadway, scene, veh)
struct FrameFeature <: AbstractFeature end

# feature(roadway, scenes, veh)
struct TemporalFeature <: AbstractFeature end
# feature(actions, veh)
struct TemporalActionFeature <: AbstractFeature end 
# feature(action, veh)
struct ActionFeature <: AbstractFeature end

# macro for automatic association of methods to traits
macro feature(fun)
    f = Main.eval(fun)
    T = typeof(f)
    if hasmethod(f, Tuple{Roadway, Entity})
        return :(featuretype(::$T) = EntityFeature())
    elseif hasmethod(f, Tuple{Roadway, Frame, Entity})
        return :(featuretype(::$T) = FrameFeature())
    elseif hasmethod(f, Tuple{Roadway, Vector{<:Frame}, Entity})
        return :(featuretype(::$T) = TemporalFeature())
    else
        throw(ErrorException("unsupported feature type"))
    end
end

# abstract type TemporalFeature <: AbstractFeature end


# Top level extract several features 
function extract_features(features, scenes::Vector{<:Frame}, ids::Vector{I}) where I 
    dfs_list = extract_feature.(features, Ref(scenes), Ref(ids))
    # join all the dataframes 
    dfs = Dict{I, DataFrame}()
    for id in ids 
        dfs[id] = reduce(hcat, df[id] for df in dfs_list)
    end
    return dfs
end



# extract one feature from a list of scene
function extract_feature(feature::Function, scenes::Vector{<:Frame}, ids::Vector{I}) where I 
    # feature_type = FEATURE_MAP[feature]
    feature_dicts = extract_feature.(Ref(feature), scenes, Ref(ids))

    # convert the list of dictionary into a dictionary of dataframes
    dfs = Dict{I, DataFrame}()
    for id in ids 
        dfs[id] = DataFrame(Pair(Symbol(feature), [f[id] for f in feature_dicts]))
    end    
    return dfs
end

# feature is a general (temporal) feature, broadcast on id only
function extract_feature(feature::AbstractFeature, scenes::Vector{<:Frame}, ids)
    values = feature.(Ref(scenes), ids)  # vector of vectors
    return Dict(zip(ids, values))
end

# feature is a frame feature, broadcast on ids and scenes
function extract_feature(feature::FrameFeature, scenes::Vector{<:Frame}, ids)
    values = broadcast(id -> feature.(scenes, id), ids)
    return Dict(zip(ids, values))
end

# feature is an entity feature, broadcast on ids and scenes 
function extract_feature(feature::EntityFeature, scenes::Vector{<:Frame}, ids)
    values = broadcast(ids) do id
        veh_hist= get_by_id.(scenes, Ref(id))
        feature.(veh_hist)
    end
    return Dict(zip(ids, values))
end

# extract one feature from one scene with different vehicle
function AutomotiveDrivingModels.extract_feature(feature::Function, scene::EntityFrame{S,D,I}, ids::Vector{I}) where {S,D,I}
    vehicles = get_by_id.(Ref(scene), ids)
    # features = extract_feature.(Ref(feature), Ref(scene), vehicles)
    features = feature.(Ref(scene), vehicles)
    return Dict(zip(ids, features))
end

# feature functions 

# posgx(scene::EntityFrame, veh::Entity) <: AbstractFeature = posg(veh).x
# posgy(scene::EntityFrame, veh::Entity) <: AbstractFeature = posg(veh).y
# posgθ(scene::EntityFrame, veh::Entity) <: AbstractFeature = posg(veh).θ
# posfs(scene::EntityFrame, veh::Entity) <: AbstractFeature = posf(veh).s
# posft(scene::EntityFrame, veh::Entity) <: AbstractFeature = posf(veh).t
# posfϕ(scene::EntityFrame, veh::Entity) <: AbstractFeature = posf(veh).ϕ
# collision(scene::EntityFrame, veh::Entity)  <: AbstractFeature = collision_checker(scene, veh.id)

# vehicle only features 

posgx(veh::Entity) = posg(veh).x
featuretype(::Type{posgx}) = EntityFeature()
posgy(veh::Entity) = posg(veh).y
featuretype(::Type{posgy}) = EntityFeature()


# posgθ(veh::Entity) <: EntityFeature = posg(veh).θ
# posfs(veh::Entity) <: EntityFeature = posf(veh).s
# posft(veh::Entity) <: EntityFeature = posf(veh).t
# posfϕ(veh::Entity) <: EntityFeature = posf(veh).ϕ

# scene features 

collision(scene::EntityFrame, veh::Entity) = collision_checker(scene, veh.id)
featuretype(::Type{collision}) = FrameFeature()

function distance_to(egoid)
    @eval begin 
        function ($(Symbol("distance_to_$(egoid)")))(scene::EntityFrame, veh::Entity) <: FrameFeature
            ego = get_by_id(scene, $egoid)
            return norm(VecE2(posg(ego) - posg(veh)))
        end
    end
end

# temporal features 

# add a new type for temporal features...
function turn_rate_g(scenes::Vector{<:Frame}, vehid)
    result = zeros(Union{Missing,Float64},length(scenes))
    angles = broadcast(x->get_by_id(x, vehid) |> posgθ, scenes)
    result[1] = missing
    result[2:end] = diff(angles)
    return result
end



# generate_feature_functions("TurnRateG", :turnrateG, Float64, "rad/s")
# function Base.get(::Feature_TurnRateG, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0; frames_back::Int=1) where {S,D,I,R}

#     id = rec[pastframe][vehicle_index].id

#     retval = FeatureValue(0.0, FeatureState.INSUF_HIST)
#     pastframe2 = pastframe - frames_back
#     if pastframe_inbounds(rec, pastframe2)

#         veh_index_curr = vehicle_index
#         veh_index_prev = findfirst(id, rec[pastframe2])

#         if veh_index_prev != nothing
#             curr = posg(rec[pastframe][veh_index_curr].state).θ
#             past = posg(rec[pastframe2][veh_index_prev].state).θ
#             Δt = get_elapsed_time(rec, pastframe2, pastframe)
#             retval = FeatureValue(deltaangle(past, curr) / Δt)
#         end
#     end

#     retval
# end




export posgx, posgy, collision, distance_to

# struct PosGFeature <: AbstractFeature end 

# function AutomotiveDrivingModels.extract_feature(::PosGFeature, scene::EntityFrame, veh::Entity)
#     posg(veh)
# end

# struct PosFFeature <: AbstractFeature end 

# function AutomotiveDrivingModels.extract_feature(::PosFFeature, scene::EntityFrame, veh::Entity)
#     posf(veh)
# end

# struct PosFSFeature <: AbstractFeature end 

# function AutomotiveDrivingModels.extract_feature(::PosFFeature, scene::EntityFrame, veh::Entity)
#     posf(veh)
# end

# struct PosFTFeature <: AbstractFeature end 

# function AutomotiveDrivingModels.extract_feature(::PosFTFeature, scene::EntityFrame, veh::Entity)
#     posf(veh)
# end

# struct VelFeature <: AbstractFeature end 

# function AutomotiveDrivingModels.extract_feature(::VelFeature, scene::EntityFrame, veh::Entity)
#     vel(veh)
# end

# struct VelGFeature <: AbstractFeature end

# function AutomotiveDrivingModels.extract_feature(::VelGFeature, scene::EntityFrame, veh::Entity)
#     velg(veh)
# end

# struct VelFFeature <: AbstractFeature end

# function AutomotiveDrivingModels.extract_feature(::VelFFeature, scene::EntityFrame, veh::Entity)
#     velf(veh)
# end

# struct CollisionFeature <: AbstractFeature end 

# function AutomotiveDrivingModels.extract_feature(::CollisionFeature, scene::EntityFrame, veh::Entity)
#     return collision_checker(scene, veh.id)
# end

# FEATURE_MAP = Dict("posg" => PosGFeature(),
#                    "posf" => PosFFeature(),
#                    "vel" => VelFeature(),
#                    "velf" => VelFFeature(),
#                    "velg" => VelGFeature())



# function Base.get(::Feature_PosFs, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     FeatureValue(posf(rec[pastframe][vehicle_index].state).s)
# end
# function Base.get(::Feature_PosFt, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     FeatureValue(posf(rec[pastframe][vehicle_index].state).t)
# end
# function Base.get(::Feature_PosFyaw, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     FeatureValue(posf(rec[pastframe][vehicle_index].state).ϕ)
# end
# function Base.get(::Feature_Speed, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     FeatureValue(vel(rec[pastframe][vehicle_index].state))
# end

# function Base.get(::Feature_VelFs, scene::Frame, roadway::R, vehicle_index::Int, pastframe::Int=0) where {R}
#     veh = scene[vehicle_index]
#     FeatureValue(velf(veh.state).s)
# end
# function Base.get(f::Feature_VelFs, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     get(f, rec[pastframe], roadway, vehicle_index)
# end

# function Base.get(::Feature_VelFt, scene::Frame, roadway::R, vehicle_index::Int, pastframe::Int=0) where {R}
#     veh = scene[vehicle_index]
#     FeatureValue(velf(veh.state).t)
# end
# function Base.get(f::Feature_VelFt, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     get(f, rec[pastframe], roadway, vehicle_index)
# end

# generate_feature_functions("TurnRateG", :turnrateG, Float64, "rad/s")
# function Base.get(::Feature_TurnRateG, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0; frames_back::Int=1) where {S,D,I,R}

#     id = rec[pastframe][vehicle_index].id

#     retval = FeatureValue(0.0, FeatureState.INSUF_HIST)
#     pastframe2 = pastframe - frames_back
#     if pastframe_inbounds(rec, pastframe2)

#         veh_index_curr = vehicle_index
#         veh_index_prev = findfirst(id, rec[pastframe2])

#         if veh_index_prev != nothing
#             curr = posg(rec[pastframe][veh_index_curr].state).θ
#             past = posg(rec[pastframe2][veh_index_prev].state).θ
#             Δt = get_elapsed_time(rec, pastframe2, pastframe)
#             retval = FeatureValue(deltaangle(past, curr) / Δt)
#         end
#     end

#     retval
# end
# generate_feature_functions("TurnRateF", :turnrateF, Float64, "rad/s")
# function Base.get(::Feature_TurnRateF, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     _get_feature_derivative_backwards(POSFYAW, rec, roadway, vehicle_index, pastframe)
# end
# generate_feature_functions("AngularRateG", :angrateG, Float64, "rad/s²")
# function Base.get(::Feature_AngularRateG, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     _get_feature_derivative_backwards(TURNRATEG, rec, roadway, vehicle_index, pastframe)
# end
# generate_feature_functions("AngularRateF", :angrateF, Float64, "rad/s²")
# function Base.get(::Feature_AngularRateF, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0) where {S,D,I,R}
#     _get_feature_derivative_backwards(TURNRATEF, rec, roadway, vehicle_index, pastframe)
# end
# generate_feature_functions("DesiredAngle", :desang, Float64, "rad")
# function Base.get(::Feature_DesiredAngle, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0; 
#     kp_desired_angle::Float64 = 1.0,
#     ) where {S,D,I,R}

#     retval = FeatureValue(0.0, FeatureState.INSUF_HIST)
#     if pastframe_inbounds(rec, pastframe) && pastframe_inbounds(rec, pastframe-1)

#         id = rec[pastframe][vehicle_index].id

#         pastϕ = posf(get_state(rec, id, pastframe-1)).ϕ
#         currϕ = posf(get_state(rec, id, pastframe)).ϕ

#         Δt = rec.timestep
#         expconst = exp(-kp_desired_angle*Δt)
#         retval = FeatureValue((currϕ - pastϕ*expconst) / (1.0 - expconst))
#     end
#     retval
# end

# generate_feature_functions("MarkerDist_Left", :d_ml, Float64, "m")
# Base.get(::Feature_MarkerDist_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0) =
#     FeatureValue(get_markerdist_left(rec[pastframe][vehicle_index], roadway))

# generate_feature_functions("MarkerDist_Right", :d_mr, Float64, "m")
# Base.get(::Feature_MarkerDist_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0) =
#     FeatureValue(get_markerdist_right(rec[pastframe][vehicle_index], roadway))

# generate_feature_functions("MarkerDist_Left_Left", :d_mll, Float64, "m", can_be_missing=true)
# function Base.get(::Feature_MarkerDist_Left_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     #=
#     Distance to the left lane marker one lane to the left
#     =#

#     veh = rec[pastframe][vehicle_index]
#     lane = get_lane(roadway, veh)
#     if n_lanes_left(lane, roadway) > 0
#         offset = posf(veh.state).t
#         lane_left = roadway[LaneTag(lane.tag.segment, lane.tag.lane + 1)]
#         FeatureValue(lane.width/2 - offset + lane_left.width)
#     else
#         FeatureValue(NaN, FeatureState.MISSING) # there is no left lane
#     end
# end
# generate_feature_functions("MarkerDist_Right_Right", :d_mrr, Float64, "m", can_be_missing=true)
# function Base.get(::Feature_MarkerDist_Right_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     #=
#     Distance to the right lane marker one lane to the right
#     =#

#     veh = rec[pastframe][vehicle_index]
#     lane = get_lane(roadway, veh)
#     if n_lanes_right(lane, roadway) > 0
#         offset = posf(veh.state).t
#         lane_right = roadway[LaneTag(lane.tag.segment, lane.tag.lane - 1)]
#         FeatureValue(lane.width/2 + offset + lane_right.width)
#     else
#         FeatureValue(NaN, FeatureState.MISSING) # there is no right lane
#     end
# end
# generate_feature_functions("RoadEdgeDist_Left", :d_edgel, Float64, "m")
# function Base.get(::Feature_RoadEdgeDist_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     veh = rec[pastframe][vehicle_index]
#     offset = posf(veh.state).t
#     footpoint = get_footpoint(veh)
#     seg = roadway[get_lane(roadway, veh.state).tag.segment]
#     lane = seg.lanes[end]
#     roadproj = proj(footpoint, lane, roadway)
#     curvept = roadway[RoadIndex(roadproj)]
#     lane = roadway[roadproj.tag]
#     FeatureValue(lane.width/2 + norm(VecE2(curvept.pos - footpoint)) - offset)
# end
# generate_feature_functions("RoadEdgeDist_Right", :d_edger, Float64, "m")
# function Base.get(::Feature_RoadEdgeDist_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     veh = rec[pastframe][vehicle_index]
#     offset = posf(veh.state).t
#     footpoint = get_footpoint(veh)
#     seg = roadway[get_lane(roadway, veh).tag.segment]
#     lane = seg.lanes[1]
#     roadproj = proj(footpoint, lane, roadway)
#     curvept = roadway[RoadIndex(roadproj)]
#     lane = roadway[roadproj.tag]
#     FeatureValue(lane.width/2 + norm(VecE2(curvept.pos - footpoint)) + offset)
# end
# generate_feature_functions("LaneOffsetLeft", :posFtL, Float64, "m", can_be_missing=true)
# function Base.get(::Feature_LaneOffsetLeft, scene::Frame, roadway::Roadway, vehicle_index::Int)
#     veh_ego = scene[vehicle_index]
#     t = posf(veh_ego.state).t
#     lane = get_lane(roadway, veh_ego)
#     if n_lanes_left(lane, roadway) > 0
#         lane_left = roadway[LaneTag(lane.tag.segment, lane.tag.lane + 1)]
#         lane_offset = t - lane.width/2 - lane_left.width/2
#         FeatureValue(lane_offset)
#     else
#         FeatureValue(NaN, FeatureState.MISSING)
#     end
# end
# function Base.get(f::Feature_LaneOffsetLeft, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     get(f, rec[pastframe], roadway, vehicle_index)
# end
# generate_feature_functions("LaneOffsetRight", :posFtR, Float64, "m", can_be_missing=true)
# function Base.get(::Feature_LaneOffsetRight, scene::Frame, roadway::Roadway, vehicle_index::Int)
#     veh_ego = scene[vehicle_index]
#     t = posf(veh_ego.state).t
#     lane = get_lane(roadway, veh_ego)
#     if n_lanes_right(lane, roadway) > 0
#         lane_right = roadway[LaneTag(lane.tag.segment, lane.tag.lane - 1)]
#         lane_offset = t + lane.width/2 + lane_right.width/2
#         FeatureValue(lane_offset)
#     else
#         FeatureValue(NaN, FeatureState.MISSING)
#     end
# end
# function Base.get(f::Feature_LaneOffsetRight, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     get(f, rec[pastframe], roadway, vehicle_index)
# end
# generate_feature_functions("N_Lane_Right", :n_lane_right, Int, "-", lowerbound=0.0)
# function Base.get(::Feature_N_Lane_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     nlr = get_lane(roadway, rec[pastframe][vehicle_index]).tag.lane - 1
#     FeatureValue(convert(Float64, nlr))
# end
# generate_feature_functions("N_Lane_Left", :n_lane_left, Int, "-", lowerbound=0.0)
# function Base.get(::Feature_N_Lane_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     veh = rec[pastframe][vehicle_index]
#     seg = roadway[get_lane(roadway, veh).tag.segment]
#     nll = length(seg.lanes) - get_lane(roadway, veh).tag.lane
#     FeatureValue(convert(Float64, nll))
# end
# generate_feature_functions("Has_Lane_Right", :has_lane_right, Bool, "-", lowerbound=0.0, upperbound=1.0)
# function Base.get(::Feature_Has_Lane_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     val = get(N_LANE_RIGHT, rec, roadway, vehicle_index, pastframe).v > 0.0
#     FeatureValue(convert(Float64, val))
# end
# generate_feature_functions("Has_Lane_Left", :has_lane_left, Bool, "-", lowerbound=0.0, upperbound=1.0)
# function Base.get(::Feature_Has_Lane_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     val = get(N_LANE_LEFT, rec, roadway, vehicle_index, pastframe).v > 0.0
#     FeatureValue(convert(Float64, val))
# end
# generate_feature_functions("LaneCurvature", :curvature, Float64, "1/m", can_be_missing=true)
# function Base.get(::Feature_LaneCurvature, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     veh = rec[pastframe][vehicle_index]
#     curvept = roadway[posf(veh.state).roadind]
#     val = curvept.k
#     if isnan(val)
#         FeatureValue(0.0, FeatureState.MISSING)
#     else
#         FeatureValue(val)
#     end
# end

# # Dist_Merge
# # Dist_Split

# generate_feature_functions("TimeToCrossing_Right", :ttcr_mr, Float64, "s", lowerbound=0.0, censor_hi=10.0)
# function Base.get(::Feature_TimeToCrossing_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     d_mr = get(MARKERDIST_RIGHT, rec, roadway, vehicle_index, pastframe).v
#     velFt = get(VELFT, rec, roadway, vehicle_index, pastframe).v

#     if d_mr > 0.0 && velFt < 0.0
#         FeatureValue(-d_mr / velFt)
#     else
#         FeatureValue(Inf)
#     end
# end
# generate_feature_functions("TimeToCrossing_Left", :ttcr_ml, Float64, "s", lowerbound=0.0, censor_hi=10.0)
# function Base.get(::Feature_TimeToCrossing_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     d_ml = get(MARKERDIST_RIGHT, rec, roadway, vehicle_index, pastframe).v
#     velFt = get(VELFT, rec, roadway, vehicle_index, pastframe).v

#     if d_ml > 0.0 && velFt < 0.0
#         FeatureValue(-d_ml / velFs)
#     else
#         FeatureValue(Inf)
#     end
# end
# generate_feature_functions("EstimatedTimeToLaneCrossing", :est_ttcr, Float64, "s", lowerbound=0.0, censor_hi=10.0)
# function Base.get(::Feature_EstimatedTimeToLaneCrossing, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     ttcr_left = get(TIMETOCROSSING_LEFT, rec, roadway, vehicle_index, pastframe).v
#     ttcr_right = get(TIMETOCROSSING_RIGHT, rec, roadway, vehicle_index, pastframe).v
#     FeatureValue(min(ttcr_left, ttcr_right))
# end
# generate_feature_functions("A_REQ_StayInLane", :a_req_stayinlane, Float64, "m/s²", can_be_missing=true)
# function Base.get(::Feature_A_REQ_StayInLane, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     velFt = get(VELFT, rec, roadway, vehicle_index, pastframe).v

#     if velFt > 0.0
#         d_mr = get(MARKERDIST_RIGHT, rec, roadway, vehicle_index, pastframe).v
#         if d_mr > 0.0
#             return FeatureValue(0.5velFt*velFt / d_mr)
#         else
#             return FeatureValue(NaN, FeatureState.MISSING)
#         end
#     else
#         d_ml = get(MARKERDIST_LEFT, rec, roadway, vehicle_index, pastframe)
#         if d_ml < 0.0
#             return FeatureValue(-0.5velFt*velFt / d_ml)
#         else
#             return FeatureValue(NaN, FeatureState.MISSING)
#         end
#     end
# end

# generate_feature_functions("Time_Consecutive_Brake", :time_consec_brake, Float64, "s", lowerbound=0.0)
# function Base.get(::Feature_Time_Consecutive_Brake, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)

#     prev_accel = convert(Float64, get(ACC, rec, roadway, vehicle_index, pastframe))
#     if prev_accel ≥ 0.0
#         FeatureValue(0.0)
#     else
#         pastframe_orig = pastframe
#         id = rec[pastframe][vehicle_index].id
#         while pastframe_inbounds(rec, pastframe-1) &&
#               get(ACC, rec, roadway, findfirst(id, rec[pastframe-1])) < 0.0

#             pastframe -= 1
#         end

#         FeatureValue(get_elapsed_time(rec, pastframe, pastframe_orig))
#     end
# end
# generate_feature_functions("Time_Consecutive_Accel", :time_consec_accel, Float64, "s", lowerbound=0.0)
# function Base.get(::Feature_Time_Consecutive_Accel, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)

#     prev_accel = convert(Float64, get(ACC, rec, roadway, vehicle_index, pastframe))
#     if prev_accel ≤ 0.0
#         FeatureValue(0.0)
#     else

#         pastframe_orig = pastframe
#         id = rec[pastframe][vehicle_index].id
#         while pastframe_inbounds(rec, pastframe-1) &&
#               get(ACC, rec, roadway, findfirst(id, rec[pastframe-1])) > 0.0

#             pastframe -= 1
#         end

#         FeatureValue(get_elapsed_time(rec, pastframe, pastframe_orig))
#     end
# end
# generate_feature_functions("Time_Consecutive_Throttle", :time_consec_throttle, Float64, "s", lowerbound=0.0)
# function Base.get(::Feature_Time_Consecutive_Throttle, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0)
#     tc_accel = get(TIME_CONSECUTIVE_ACCEL, rec, roadway, vehicle_index, pastframe).v
#     tc_brake = get(TIME_CONSECUTIVE_BRAKE, rec, roadway, vehicle_index, pastframe).v
#     FeatureValue(tc_accel ≥ tc_brake ? tc_accel : -tc_brake)
# end

# #############################################
# #
# # FRONT
# #
# #############################################

# generate_feature_functions("Dist_Front", :d_front, Float64, "m", lowerbound=0.0, can_be_missing=true)
# function Base.get(::Feature_Dist_Front, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_lane(rec[pastframe], vehicle_index, roadway),
#     censor_hi::Float64=100.0,
#     )

#     if neighborfore.ind == nothing
#         FeatureValue(100.0, FeatureState.CENSORED_HI)
#     else
#         scene = rec[pastframe]
#         len_ego = length(scene[vehicle_index].def)
#         len_oth = length(scene[neighborfore.ind].def)
#         FeatureValue(neighborfore.Δs - len_ego/2 - len_oth/2)
#     end
# end
# generate_feature_functions("Speed_Front", :v_front, Float64, "m/s", can_be_missing=true)
# function Base.get(::Feature_Speed_Front, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_lane(rec[pastframe], vehicle_index, roadway),
#     )

#     if neighborfore.ind == nothing
#         FeatureValue(0.0, FeatureState.MISSING)
#     else
#         FeatureValue(vel(rec[pastframe][neighborfore.ind].state))
#     end
# end
# generate_feature_functions("Timegap", :timegap, Float64, "s", can_be_missing=true)
# function Base.get(::Feature_Timegap, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_lane(rec[pastframe], vehicle_index, roadway),
#     censor_hi::Float64 = 10.0,
#     )

#     v = vel(rec[pastframe][vehicle_index].state)

#     if v ≤ 0.0 || neighborfore.ind == nothing
#         FeatureValue(censor_hi, FeatureState.CENSORED_HI)
#     else
#         scene = rec[pastframe]
#         len_ego = length(scene[vehicle_index].def)
#         len_oth = length(scene[neighborfore.ind].def)
#         Δs = neighborfore.Δs - len_ego/2 - len_oth/2

#         if Δs > 0.0
#             FeatureValue(Δs / v)
#         else
#             FeatureValue(0.0) # collision!
#         end
#     end
# end

# generate_feature_functions("Inv_TTC", :inv_ttc, Float64, "1/s", can_be_missing=true)
# function Base.get(::Feature_Inv_TTC, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_lane(rec[pastframe], vehicle_index, roadway),
#     censor_hi::Float64 = 10.0,
#     )


#     if neighborfore.ind == nothing
#         FeatureValue(0.0, FeatureState.MISSING)
#     else
#         scene = rec[pastframe]
#         veh_fore = scene[neighborfore.ind]
#         veh_rear = scene[vehicle_index]

#         len_ego = length(veh_fore.def)
#         len_oth = length(veh_rear.def)
#         Δs = neighborfore.Δs - len_ego/2 - len_oth/2


#         Δv = vel(veh_fore.state) - vel(veh_rear.state)

#         if Δs < 0.0 # collision!
#             FeatureValue(censor_hi, FeatureState.CENSORED_HI)
#         elseif Δv > 0.0 # front car is pulling away
#             FeatureValue(0.0)
#         else
#             f = -Δv/Δs
#             if f > censor_hi
#                 FeatureValue(f, FeatureState.CENSORED_HI)
#             else
#                 FeatureValue(f)
#             end
#         end
#     end
# end
# generate_feature_functions("TTC", :ttc, Float64, "s", can_be_missing=true)
# function Base.get(::Feature_TTC, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_lane(rec[pastframe], vehicle_index, roadway),
#     censor_hi::Float64 = 10.0,
#     inv_ttc::FeatureValue = get(INV_TTC, rec, roadway, vehicle_index, pastframe, neighborfore=neighborfore, censor_hi=censor_hi),
#     )

#     if inv_ttc.i == FeatureState.MISSING
#         # if the value is missing then front car not found and set TTC to censor_hi
#         return FeatureValue(censor_hi, FeatureState.MISSING)
#     else
#         @assert is_feature_valid(inv_ttc) || inv_ttc.i == FeatureState.CENSORED_HI
#         return FeatureValue(min(1.0 / inv_ttc.v, censor_hi))
#     end
# end

# #############################################
# #
# # FRONT LEFT
# #
# #############################################
# generate_feature_functions("Dist_Front_Left", :d_front_left, Float64, "m", lowerbound=0.0, can_be_missing=true)
# function Base.get(::Feature_Dist_Front_Left, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_left_lane(rec[pastframe], vehicle_index, roadway),
#     )

#     get(DIST_FRONT, rec, roadway, vehicle_index, pastframe, neighborfore=neighborfore)
# end

# #############################################
# #
# # FRONT RIGHT
# #
# #############################################

# generate_feature_functions("Dist_Front_Right", :d_front_right, Float64, "m", lowerbound=0.0, can_be_missing=true)
# function Base.get(::Feature_Dist_Front_Right, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborfore::NeighborLongitudinalResult = get_neighbor_fore_along_right_lane(rec[pastframe], vehicle_index, roadway),
#     )

#     get(DIST_FRONT, rec, roadway, vehicle_index, pastframe, neighborfore=neighborfore)
# end

# #############################################
# #
# # REAR
# #
# #############################################

# generate_feature_functions("Dist_Rear", :d_rear, Float64, "m", lowerbound=0.0, can_be_missing=true)
# function Base.get(::Feature_Dist_Rear, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborrear::NeighborLongitudinalResult = get_neighbor_rear_along_lane(rec[pastframe], vehicle_index, roadway),
#     censor_hi::Float64=100.0,
#     )

#     if neighborrear.ind == nothing
#         FeatureValue(100.0, FeatureState.CENSORED_HI)
#     else
#         scene = rec[pastframe]
#         len_ego = length(scene[vehicle_index].def)
#         len_oth = length(scene[neighborrear.ind].def)
#         FeatureValue(neighborrear.Δs - len_ego/2 - len_oth/2)
#     end
# end
# generate_feature_functions("Speed_Rear", :v_rear, Float64, "m/s", can_be_missing=true)
# function Base.get(::Feature_Speed_Rear, rec::SceneRecord, roadway::Roadway, vehicle_index::Int, pastframe::Int=0;
#     neighborrear::NeighborLongitudinalResult = get_neighbor_rear_along_lane(rec[pastframe], vehicle_index, roadway),
#     )

#     if neighborrear.ind == nothing
#         FeatureValue(0.0, FeatureState.MISSING)
#     else
#         FeatureValue(vel(rec[pastframe][neighborrear.ind].state))
#     end
# end

# #############################################
# #
# # SCENE WISE
# #
# #############################################

# generate_feature_functions("Is_Colliding", :is_colliding, Bool, "-", lowerbound=0.0, upperbound=1.0)
# function Base.get(::Feature_Is_Colliding, rec::EntityQueueRecord{S,D,I}, roadway::R, vehicle_index::Int, pastframe::Int=0;
#     mem::CPAMemory=CPAMemory(),
#     ) where {S,D,I,R}

#     scene = rec[pastframe]
#     is_colliding = convert(Float64, get_first_collision(scene, vehicle_index, mem).is_colliding)
#     FeatureValue(is_colliding)
# end

# # WOULD BE NICE: Base.get(scene::Frame{E}, roadway::Roadway, :n_lane_left, :ego)
# # TODO: Define macro that takes care of calling generate_feature_functions
