-- Spherical quadrangle interpolation
------------------------------------------------------------
-- Copyright (c) 2019 Parker Stebbins
-- Distributed under the MIT license; see LICENSE file.
-- github.com/Fraktality/squad

local abs   = math.abs
local sin   = math.sin
local cos   = math.cos
local sqrt  = math.sqrt
local atan2 = math.atan2

-- log(q0*inv(q1))
local function invLogProduct(w0, x0, y0, z0, w1, x1, y1, z1)
	local w = w0*w1 + x0*x1 + y0*y1 + z0*z1
	local x = w0*x1 - x0*w1 + y0*z1 - z0*y1
	local y = w0*y1 - x0*z1 - y0*w1 + z0*x1
	local z = w0*z1 + x0*y1 - y0*x1 - z0*w1

	local v = sqrt(x*x + y*y + z*z)
	local t = v > 1e-4 and atan2(v, w)/(4*v) or 8/21 + w*(-27/140 + w*(8/105 - w/70))
	return x*t, y*t, z*t
end

-- generate a control rotation from three quats
local function controlRotation(w0, x0, y0, z0, w1, x1, y1, z1, w2, x2, y2, z2)
	if w0*w1 + x0*x1 + y0*y1 + z0*z1 < 0 then
		w0, x0, y0, z0 = -w0, -x0, -y0, -z0
	end
	if w2*w1 + x2*x1 + y2*y1 + z2*z1 < 0 then
		w2, x2, y2, z2 = -w2, -x2, -y2, -z2
	end

	local bx0, by0, bz0 = invLogProduct(w0, x0, y0, z0, w1, x1, y1, z1)
	local bx1, by1, bz1 = invLogProduct(w2, x2, y2, z2, w1, x1, y1, z1)

	local mx = bx0 + bx1
	local my = by0 + by1
	local mz = bz0 + bz1

	local n = sqrt(mx*mx + my*my + mz*mz)
	local m = n > 1e-4 and sin(n)/n or 1 + n*n*(n*n/120 - 1/6)

	local ew = cos(n)
	local ex = m*mx
	local ey = m*my
	local ez = m*mz

	return ew*w1 - ex*x1 - ey*y1 - ez*z1,
	       ex*w1 + ew*x1 - ez*y1 + ey*z1,
	       ey*w1 + ez*x1 + ew*y1 - ex*z1,
	       ez*w1 - ey*x1 + ex*y1 + ew*z1
end

local function slerp(t, w0, x0, y0, z0, w1, x1, y1, z1, d)
	local t0, t1
	if d < 0.9999 then
		local d0 = y0*x1 + w0*z1 - x0*y1 - z0*w1
		local d1 = y0*w1 - w0*y1 + z0*x1 - x0*z1
		local d2 = y0*z1 - w0*x1 - z0*y1 + x0*w1
		local theta = atan2(sqrt(d0*d0 + d1*d1 + d2*d2), d)
		local rsa = sqrt(1 - d*d)
		t0, t1 = sin((1 - t)*theta)/rsa, sin(t*theta)/rsa
	else
		t0, t1 = 1 - t, t
	end
	return w0*t0 + w1*t1,
	       x0*t0 + x1*t1,
	       y0*t0 + y1*t1,
	       z0*t0 + z1*t1
end

local function squad(q0, q1, q2, q3)
	local q1w, q1x, q1y, q1z = q1[1], q1[2], q1[3], q1[4]
	local q2w, q2x, q2y, q2z = q2[1], q2[2], q2[3], q2[4]

	local p0w, p0x, p0y, p0z = controlRotation(
		q0[1], q0[2], q0[3], q0[4],
		q1w, q1x, q1y, q1z,
		q2w, q2x, q2y, q2z
	)
	local p1w, p1x, p1y, p1z = controlRotation(
		q1w, q1x, q1y, q1z,
		q2w, q2x, q2y, q2z,
		q3[1], q3[2], q3[3], q3[4]
	)

	local dq = q1w*q2w + q1x*q2x + q1y*q2y + q1z*q2z
	local dp = abs(p0w*p1w + p0x*p1x + p0y*p1y + p0z*p1z)

	if dq < 0 then
		p1w, p1x, p1y, p1z = -p1w, -p1x, -p1y, -p1z
		q2w, q2x, q2y, q2z = -q2w, -q2x, -q2y, -q2z
		dq = -dq
	end

	return function(t)
		local w0, x0, y0, z0 = slerp(t, q1w, q1x, q1y, q1z, q2w, q2x, q2y, q2z, dq)
		local w1, x1, y1, z1 = slerp(t, p0w, p0x, p0y, p0z, p1w, p1x, p1y, p1z, dp)

		return slerp(2*t*(1 - t), w0, x0, y0, z0, w1, x1, y1, z1, w0*w1 + x0*x1 + y0*y1 + z0*z1)
	end
end

return squad
