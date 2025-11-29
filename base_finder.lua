-- Assume minetest.get_current_mods() is not nil for API access
-- Simulating necessary Minetest vector functions for context:
-- local vector = minetest.get_current_mods().vector

-- NOTE: In a real Minetest environment, these functions are already global or in the 'vector' table.
local function distance_sq(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return dx*dx + dy*dy + dz*dz
end

-- Function to find all neighbors within epsilon distance
local function region_query(positions, index, epsilon_sq)
    local neighbors = {}
    local current_pos = positions[index]

    for i = 1, #positions do
        if i ~= index then
            -- Use distance_sq for comparison to avoid expensive math.sqrt()
            if distance_sq(current_pos, positions[i]) <= epsilon_sq then
                table.insert(neighbors, i)
            end
        end
    end
    return neighbors
end

-- Function to expand a cluster
local function expand_cluster(positions, current_index, neighbors, current_cluster, epsilon_sq, min_pts, visited)
    -- Add the core point to the cluster and mark as visited
    visited[current_index] = true
    table.insert(current_cluster, positions[current_index])

    -- Use a stack/queue for iterative expansion
    local frontier = neighbors

    for i = 1, #frontier do
        local neighbor_index = frontier[i]

        if not visited[neighbor_index] then
            visited[neighbor_index] = true
            
            local neighbor_neighbors = region_query(positions, neighbor_index, epsilon_sq)

            if #neighbor_neighbors >= min_pts then
                -- Add new neighbors to the frontier for further processing
                for _, new_index in ipairs(neighbor_neighbors) do
                    -- Only add unvisited points to avoid infinite loops and re-processing
                    if not visited[new_index] then
                        table.insert(frontier, new_index)
                    end
                end
            end

            -- Add the neighbor (core or border point) to the current cluster
            table.insert(current_cluster, positions[neighbor_index])
        
        -- If neighbor is already visited, it must be part of another cluster, 
        -- but if it's not currently in a cluster, it means it was a border point of 
        -- an *already processed* cluster, which we ignore here to maintain separation.
        -- We only need to ensure the current neighbor is added if it hasn't been added yet (handled by the initial check).
        end
    end
end

-- The main DBSCAN function
function herob.dbscan_base_decider(positions, epsilon, min_pts)
    local clusters = {}
    local visited = {}
    local epsilon_sq = epsilon * epsilon -- Pre-calculate epsilon squared

    -- 1. Iterate through all positions
    for i = 1, #positions do
        if not visited[i] then
            -- Mark as visited before query to avoid double processing if it's noise
            visited[i] = true
            
            -- 2. Find neighbors for the current point
            local neighbors = region_query(positions, i, epsilon_sq)

            -- 3. Check if the point is a Core Point
            if #neighbors >= min_pts then
                local new_cluster = {}
                
                -- Expand the cluster from this core point
                expand_cluster(positions, i, neighbors, new_cluster, epsilon_sq, min_pts, visited)
                
                -- Add the finished cluster (base) to the list
                table.insert(clusters, new_cluster)
            
            -- 4. If not a core point, it's marked as visited and remains noise until 
            --    a core point's expansion adds it (making it a border point).
            --    If it's not added, it remains noise.
            end
        end
    end

    return clusters
end

function herob.get_mean_cluster_center(cluster)
    local num_blocks = #cluster
    -- Set the sample size to a maximum of 100, or the total number of blocks
    local sample_size = math.min(num_blocks, 100)
    
    local sum_x, sum_y, sum_z = 0, 0, 0
    
    if num_blocks == 0 then
        -- Return a nil position if the cluster is empty
        return {x=0, y=0, z=0} 
    end

    -- If the cluster is small enough, calculate the exact centroid (no sampling needed)
    if num_blocks <= 100 then
        for i = 1, num_blocks do
            local pos = cluster[i]
            sum_x = sum_x + pos.x
            sum_y = sum_y + pos.y
            sum_z = sum_z + pos.z
        end
    else
        -- Logic for random sampling without replacement (for clusters > 100 blocks)
        local used_indices = {} -- Map to track indices already selected
        local sampled_count = 0

        while sampled_count < sample_size do
            -- Generate a random index between 1 and the total number of blocks
            local rand_idx = math.random(1, num_blocks)
            
            -- If this index hasn't been used yet, process it
            if not used_indices[rand_idx] then
                used_indices[rand_idx] = true
                sampled_count = sampled_count + 1
                
                local pos = cluster[rand_idx]
                sum_x = sum_x + pos.x
                sum_y = sum_y + pos.y
                sum_z = sum_z + pos.z
            end
            -- Optimization: if we've checked too many times without finding a new index, 
            -- it means we're close to filling the sample, but in practice, for N=100
            -- and a large cluster, this while loop is fast enough.
        end
    end
    
    -- Calculate the average (mean) position
    local centroid = {
        x = sum_x / sample_size,
        y = sum_y / sample_size,
        z = sum_z / sample_size
    }
    
    return centroid
end