-- This is a FIXED version with all goto statements removed
-- Copy the contents from your original SplashbotPROOF.lua
-- Then replace the segment processing section (around lines 499-597) with this:

local minR = 8
local maxR = math.min(maxProbeDist, MAX_SEGMENT_RADIUS)
if maxR > minR then
	local cached = cachedRadii[playerIdx][planeId][seg]
	local prevR = cached and cached.radius
	local trPrev = nil
	if prevR and prevR >= minR and prevR <= maxR then
		trPrev = TraceSurface(prevR)
	end
	local trMax = TraceSurface(maxR)
	local trMin = nil
	local shouldSkip = false

	if (not trPrev) and not trMax then
		trMin = TraceSurface(minR)
		if not trMin then
			shouldSkip = true
		end
	end

	if not shouldSkip then
		local low = minR
		local high = maxR
		if cached and cached.low and cached.high then
			low = math.max(minR, cached.low)
			high = math.min(maxR, cached.high)
		end

		local bestR = nil
		local bestPos = nil
		local bestFrac = nil
		local bestN = nil

		if trPrev and prevR and prevR >= minR and prevR <= maxR then
			local okPrevR, posPrevR, fracPrevR, nPrevR = EvalTrace(trPrev)
			if okPrevR then
				bestR, bestPos, bestFrac, bestN = prevR, posPrevR, fracPrevR, nPrevR
				low = prevR
			end
		end

		local okMax, posMax, fracMax, nMax = EvalTrace(trMax)
		if okMax then
			bestR, bestPos, bestFrac, bestN = maxR, posMax, fracMax, nMax
		else
			if not bestR then
				if not trMin then
					trMin = TraceSurface(minR)
				end
				local okMin, posMin, fracMin, nMin = EvalTrace(trMin)
				if okMin then
					bestR, bestPos, bestFrac, bestN = minR, posMin, fracMin, nMin
					low = minR
				else
					local midR = (minR + maxR) * 0.5
					local okMid, posMid, fracMid, nMid = EvalRadius(midR)
					if okMid then
						bestR, bestPos, bestFrac, bestN = midR, posMid, fracMid, nMid
						low = midR
					else
						shouldSkip = true
					end
				end
			end

			if not shouldSkip then
				high = maxR
				local iterCount = math.min(SEGMENT_SEARCH_ITERATIONS, 4)
				for _ = 1, iterCount do
					if (high - low) <= SEGMENT_SEARCH_EPSILON then
						break
					end
					local mid = (low + high) * 0.5
					local okMid, posMid, fracMid, nMid = EvalRadius(mid)
					if okMid then
						bestR, bestPos, bestFrac, bestN = mid, posMid, fracMid, nMid
						low = mid
					else
						high = mid
					end
				end
			end
		end

		if not shouldSkip and bestR and bestR >= 10 then
			if prevR and math.abs(bestR - prevR) < RADIUS_HYSTERESIS then
				local okPrev, posPrev, fracPrev, nPrev = EvalRadius(prevR)
				if okPrev then
					bestR, bestPos, bestFrac, bestN = prevR, posPrev, fracPrev, nPrev
				end
			end
			cachedRadii[playerIdx][planeId][seg] = {
				radius = bestR,
				low = bestR - RADIUS_TOLERANCE,
				high = bestR + RADIUS_TOLERANCE,
			}

			table.insert(points, {
				pos = bestPos,
				fraction = bestFrac or 1.0,
				radius = bestR,
				normal = bestN or planeNormal,
				segmentIndex = seg,
				planeId = planeId,
			})
		end
	end
end
