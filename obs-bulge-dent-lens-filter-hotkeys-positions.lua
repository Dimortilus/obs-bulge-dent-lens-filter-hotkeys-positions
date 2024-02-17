-- Thank you: khaver, Suslik V, UpgradeQ, nleseul, Oncorporation, Keith Schneider, DavidKMagnus, timotheeg, and many others 
--  for your invaluable insights on OBS scripting and shaders
-- Based on obs-shaderfilter by nleseul & Oncorporation https://github.com/Oncorporation/obs-shaderfilter/
--  and Dent/Bulge distortion filter by timotheeg https://github.com/timotheeg/distort_faces
-- Tweaking and slapping together a bunch of different stuff by Dimortilus
local obs = obslua
bit = require("bit")

-- Bulge/Dent variables
TEXT_FILTER_NAME = 'Bulge/Dent lens filter (with hotkeys for positions)'
TEXT_BULGE_SCALE = 'Scale ( < 1 = Dent, > 1 = Bulge )'
TEXT_BULGE_RADIUS = 'Radius (based on side length)'
TEXT_BULGE_CENTER_X_NORM = 'Lens center X (normalized)'
TEXT_BULGE_CENTER_Y_NORM = 'Lens center Y (normalized)'
TEXT_BULGE_RADIUS_LENGTH_SHORTER_SIDE = 'Base the radius on length of the shorter side'
TEXT_BULGE_SHOW_LENS_BORDER = 'Show lens border'
TEXT_BULGE_SHOW_LENS_CENTER = 'Show lens center'

SETTING_BULGE_SCALE = 'bulge_scale'
SETTING_BULGE_RADIUS = 'bulge_radius'
SETTING_BULGE_CENTER_X_NORM = 'bulge_center_x_norm'
SETTING_BULGE_CENTER_Y_NORM = 'bulge_center_y_norm'
SETTING_BULGE_RADIUS_LENGTH_SHORTER_SIDE = 'bulge_radius_length_shorter_side'
SETTING_BULGE_SHOW_LENS_BORDER = 'bulge_show_lens_border'
SETTING_BULGE_SHOW_LENS_CENTER = 'bulge_show_lens_center'

-- Definition of the global variable containing the source_info structure https://obsproject.com/docs/reference-sources.html
source_info = {}
source_info.id = 'filter-bulge-dent-lens'
source_info.type = obslua.OBS_SOURCE_TYPE_FILTER
source_info.output_flags = bit.bor(obslua.OBS_SOURCE_VIDEO)

function set_render_size(filter)
	local target = obslua.obs_filter_get_target(filter.context)

	local width, height
	if target == nil then
		width = 0
		height = 0
	else
		width = obslua.obs_source_get_base_width(target)
		height = obslua.obs_source_get_base_height(target)
	end

	filter.width = width
	filter.height = height
end

source_info.get_width = function(filter)
	return filter.width
end

source_info.get_height = function(filter)
	return filter.height
end

source_info.get_name = function()
	return TEXT_FILTER_NAME
end

-- Creates the implementation data for the source
source_info.create = function(settings, source)
	-- Custom data table
	local filter = {}
	-- OBS calls shader uniforms "parameters", hence the "params" syntax
	filter.params = {}
	-- Bulge positions
	-- Set hotkeys in OBS settings: Ctrl + Numpad 3 for bottom right corner, Ctrl + Numpad 5 for center, and Ctrl + Numpad 8 for top
	filter.bulge_positions = {
		{
			pos_name = 'bottom_right',
			htk_name = 'htk_bulge_pos_bottom_right',
			htk_id = obs.OBS_INVALID_HOTKEY_ID,
			bulge_scale = 5.000,
			bulge_radius = 0.177,
			bulge_center_x_norm = 0.863,
			bulge_center_y_norm = 0.635
		},
		{
			pos_name = 'center',
			htk_name = 'htk_bulge_pos_center',
			htk_id = obs.OBS_INVALID_HOTKEY_ID,
			bulge_scale = 5.000,
			bulge_radius = 0.267,
			bulge_center_x_norm = 0.500,
			bulge_center_y_norm = 0.413
		},		
		{
			pos_name = 'top',
			htk_name = 'htk_bulge_pos_top',
			htk_id = obs.OBS_INVALID_HOTKEY_ID,
			bulge_scale = 5.000,
			bulge_radius = 0.647,
			bulge_center_x_norm = 0.500,
			bulge_center_y_norm = 0.780
		}
	}
	
	filter.created_hotkeys = false
	filter.context = source
	set_render_size(filter)
	
	obslua.obs_enter_graphics()
	-- Compiles the effect from the shader code string
	filter.effect = obslua.gs_effect_create(shader, nil, nil)
	-- [Unused] Loads the shader from file rather than from a string, 
	--  In this approach, whenever the shader is edited, for changes to take effect, the OBS needs to be restarted 
	--  (simply reloading the script is not gonna work in this case)
	--filter.effect = obslua.gs_effect_create_from_file(script_path() .. 'bulge_shader.effect', nil)
	if filter.effect ~= nil then
		-- Gets references to the parameter objects of the effect (filter.params.name point to the corresponding effect parameter objects)
		filter.params.bulge_scale = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_scale')
		filter.params.bulge_radius = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_radius')
		filter.params.bulge_center_x_norm = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_center_x_norm')
		filter.params.bulge_center_y_norm = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_center_y_norm')
		filter.params.bulge_radius_length_shorter_side = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_radius_length_shorter_side')
		filter.params.bulge_show_lens_border = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_show_lens_border')
		filter.params.bulge_show_lens_center = obslua.gs_effect_get_param_by_name(filter.effect, 'bulge_show_lens_center')
		filter.params.texture_width = obslua.gs_effect_get_param_by_name(filter.effect, 'texture_width')
		filter.params.texture_height = obslua.gs_effect_get_param_by_name(filter.effect, 'texture_height')
	end
	obslua.obs_leave_graphics()
	
	-- Calls the destroy function if the effect was not compiled properly
	if filter.effect == nil then
		source_info.destroy(filter)
		return nil
	end
	-- Register hotkeys
	source_info.register_hotkeys(filter, settings)
	-- Calls update to initialize the rest of the properties-managed settings
	source_info.update(filter, settings)
	return filter
end

-- Destroy and release resources linked to the custom filter data
source_info.destroy = function(filter)
	if filter.effect ~= nil then
		obslua.obs_enter_graphics()
		obslua.gs_effect_destroy(filter.effect)
		obslua.obs_leave_graphics()
	end
end

-- Update the internal data for this source upon settings change
source_info.update = function(filter, settings)
	filter.bulge_scale = obslua.obs_data_get_double(settings, SETTING_BULGE_SCALE)
	filter.bulge_radius = obslua.obs_data_get_double(settings, SETTING_BULGE_RADIUS)
	filter.bulge_center_x_norm = obslua.obs_data_get_double(settings, SETTING_BULGE_CENTER_X_NORM)
	filter.bulge_center_y_norm = obslua.obs_data_get_double(settings, SETTING_BULGE_CENTER_Y_NORM)
	filter.bulge_radius_length_shorter_side = obslua.obs_data_get_bool(settings, SETTING_BULGE_RADIUS_LENGTH_SHORTER_SIDE)
	filter.bulge_show_lens_border = obslua.obs_data_get_bool(settings, SETTING_BULGE_SHOW_LENS_BORDER)
	filter.bulge_show_lens_center = obslua.obs_data_get_bool(settings, SETTING_BULGE_SHOW_LENS_CENTER)
	set_render_size(filter)
end

-- Called when rendering the source with the graphics subsystem
source_info.video_render = function(filter, effect)
	if not obslua.obs_source_process_filter_begin(filter.context, obslua.GS_RGBA, obslua.OBS_NO_DIRECT_RENDERING) then return end

	-- Sets parameter (uniorm) object values of the effect (filter.params.name point to the corresponding effect parameter objects)
	obslua.gs_effect_set_float(filter.params.bulge_scale, filter.bulge_scale)
	obslua.gs_effect_set_float(filter.params.bulge_radius, filter.bulge_radius)
	obslua.gs_effect_set_float(filter.params.bulge_center_x_norm, filter.bulge_center_x_norm)
	obslua.gs_effect_set_float(filter.params.bulge_center_y_norm, filter.bulge_center_y_norm)
	obslua.gs_effect_set_bool(filter.params.bulge_radius_length_shorter_side, filter.bulge_radius_length_shorter_side)
	obslua.gs_effect_set_bool(filter.params.bulge_show_lens_border, filter.bulge_show_lens_border)
	obslua.gs_effect_set_bool(filter.params.bulge_show_lens_center, filter.bulge_show_lens_center)
	obslua.gs_effect_set_float(filter.params.texture_width, filter.width)
	obslua.gs_effect_set_float(filter.params.texture_height, filter.height)

	obslua.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

-- Build and return a properties structure filled with GUI elemetns 
source_info.get_properties = function(filter)
	local props = obslua.obs_properties_create()

	local prop_bulge_scale = obslua.obs_properties_add_float_slider(props, SETTING_BULGE_SCALE, TEXT_BULGE_SCALE, 0.25, 5.0, 0.001)
	local prop_bulge_radius = obslua.obs_properties_add_float_slider(props, SETTING_BULGE_RADIUS, TEXT_BULGE_RADIUS, 0, 1.0, 0.001)
	local prop_bulge_center_x_norm = obslua.obs_properties_add_float_slider(props, SETTING_BULGE_CENTER_X_NORM, TEXT_BULGE_CENTER_X_NORM, 0, 1.0, 0.001)
	local prop_bulge_center_y_norm = obslua.obs_properties_add_float_slider(props, SETTING_BULGE_CENTER_Y_NORM, TEXT_BULGE_CENTER_Y_NORM, 0, 1.0, 0.001)
	local prop_bulge_radius_length_shorter_side = obslua.obs_properties_add_bool(props, SETTING_BULGE_RADIUS_LENGTH_SHORTER_SIDE, TEXT_BULGE_RADIUS_LENGTH_SHORTER_SIDE)
	local prop_bulge_show_lens_border = obslua.obs_properties_add_bool(props, SETTING_BULGE_SHOW_LENS_BORDER, TEXT_BULGE_SHOW_LENS_BORDER)
	local prop_bulge_show_lens_center = obslua.obs_properties_add_bool(props, SETTING_BULGE_SHOW_LENS_CENTER, TEXT_BULGE_SHOW_LENS_CENTER)
	
	return props
end

-- Sets the default settings for this source
source_info.get_defaults = function(settings)
	obslua.obs_data_set_default_double(settings, SETTING_BULGE_SCALE, 2.5)
	obslua.obs_data_set_default_double(settings, SETTING_BULGE_RADIUS, 0.5)
	obslua.obs_data_set_default_double(settings, SETTING_BULGE_CENTER_X_NORM, 0.5)
	obslua.obs_data_set_default_double(settings, SETTING_BULGE_CENTER_Y_NORM, 0.5)
	obslua.obs_data_set_default_bool(settings, SETTING_BULGE_RADIUS_LENGTH_SHORTER_SIDE, true)
	obslua.obs_data_set_default_bool(settings, SETTING_BULGE_SHOW_LENS_BORDER, false)
	obslua.obs_data_set_default_bool(settings, SETTING_BULGE_SHOW_LENS_CENTER, false)
end

source_info.video_tick = function(filter, seconds)
	set_render_size(filter)
end

-- Register hotkeys to change the bulge settings appropriately for each position
source_info.register_hotkeys = function(filter,settings)
	-- Check whether the hotkeys have been already created
	if filter.created_hotkeys then return end
	-- Register hotkeys
	for _, position in ipairs(filter.bulge_positions) do
		position.htk_id = obslua.obs_hotkey_register_frontend(
			position.htk_name,
			'Set Bulge to the ' .. position.pos_name .. ' position',
			function(pressed)
				if not pressed then
					return
				end
				source_info.set_bulge(filter, settings, position)
			end
		)
		-- The line below is for debugging purposes
		--print('registered ' .. position.htk_name .. ' hotkey: id=' .. position.htk_id)
		local hotkey_save_array = obslua.obs_data_get_array(settings, position.htk_name)
		obslua.obs_hotkey_load(position.htk_id, hotkey_save_array)
		obslua.obs_data_array_release(hotkey_save_array)
	end
	if not filter.created_hotkeys then
		filter.created_hotkeys = true
	end
end

-- Set Bulge to the appropriate position
source_info.set_bulge = function(filter, settings, position)
	-- The line below is for debugging purposes
	--print('pressed the hotkey for the ' .. position.htk_name .. ' position')
	
	-- Set new values for the settings
	obslua.obs_data_set_double(settings, SETTING_BULGE_SCALE, position.bulge_scale)
	obslua.obs_data_set_double(settings, SETTING_BULGE_RADIUS, position.bulge_radius)
	obslua.obs_data_set_double(settings, SETTING_BULGE_CENTER_X_NORM, position.bulge_center_x_norm)
	obslua.obs_data_set_double(settings, SETTING_BULGE_CENTER_Y_NORM, position.bulge_center_y_norm)
	
	-- Update the filter with new values
	source_info.update(filter, settings)
end

-- Preserve hotkeys between obs restarts
source_info.save = function(filter,settings)
	if filter.created_hotkeys then filter.created_hotkeys = true end
	for _, position in ipairs(filter.bulge_positions) do
		local hotkey_save_array = obs.obs_hotkey_save(position.htk_id)
		obs.obs_data_set_array(settings, position.htk_name, hotkey_save_array)
		obs.obs_data_array_release(hotkey_save_array)
	end
end

-- Script description
function script_description()
	return "Adds new video effect filter named '" .. TEXT_FILTER_NAME .. "' to imitate lens distortion"
end

-- Register the "source" (filters are considred sources)
function script_load(settings)
	obs.obs_register_source(source_info)
end

-- Bulge/Dent lens shader
shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float bulge_scale;
uniform float bulge_radius;
uniform float bulge_center_x_norm;
uniform float bulge_center_y_norm;
uniform bool bulge_radius_length_shorter_side;
uniform bool bulge_show_lens_border;
uniform bool bulge_show_lens_center;
uniform float texture_width;
uniform float texture_height;

sampler_state def_sampler {
	Filter   = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
};

// Vertex data 
struct VertData {
	float4 pos : POSITION;
	float2 uv  : TEXCOORD0;
};

// Vertex Shader
VertData VSDefault(VertData vert_in)
{
	VertData vert_out;
	vert_out.pos = mul(float4(vert_in.pos.xyz, 1.0), ViewProj);
	vert_out.uv  = vert_in.uv;
	return vert_out;
}

// Pixel Shader
float4 PSDrawBare(VertData vert_in) : TARGET
{
	const float PI = 3.141592653589793238;
	// Radius of the lens (normalized)
	float lens_radius_norm = bulge_radius;
	
	// Aspect ratio of the texture
	float texture_ratio = texture_width / texture_height;
	
	// Center of the filter lens in actual coordinates of the texture's dimensions
    float2 lens_center_pos = float2(bulge_center_x_norm * texture_width, bulge_center_y_norm * texture_height);
		
	// Texture coordinates (uv coordinates are normalized to be between 0 and 1)
	float2 uv = vert_in.uv;
	// Convert to actual coordinates in the texture's dimensions
	uv = float2(uv.x * texture_width, uv.y * texture_height);
	
	/* Subtracting coordinates of the vector pointing to the center of the lens from the coordinates of the vector pointing to UV,  
	to get coordinates of a vector, whose magnitude is the distance between the current pixel and the center of the lens */
	float2 d = uv - lens_center_pos;
	
	// Calculate magnitude of that vector (distance between the current pixel and the center of the lens)
	float d_len = length(d); //sqrt(dot(d, d));
	// Radius of the lens (actual)
	float lens_radius = 0;
	// Account for texture's aspect ratio and base the radius on length of the shorter or longer side
	if (texture_ratio < 1) {
		if (bulge_radius_length_shorter_side) {
			lens_radius = lens_radius_norm * texture_width;
		} else lens_radius = lens_radius_norm * texture_height;
	} else {
		if (bulge_radius_length_shorter_side) {
			lens_radius = lens_radius_norm * texture_height;
		} else lens_radius = lens_radius_norm * texture_width;
	}
	
	// Bulge/Pinch lens
	if (d_len < lens_radius) {
		// Convert to polar coordinates of sorts (distance and angle) 
		/* Ratio, how far the current input image pixel is positioned along the lens radius
		(subtracting the ratio from 1.0 because in this particular script 
		we need to be moving in the inwards direction, from lens border to the image center) */
		float r = 1.0 - ((d_len + 0.00001) / lens_radius);
		
		/* Angle between the vector pointing to the pixel and the x-axis
		required to preserve vector direction in calculations */
		float a = atan2(d.y, d.x);
		
		/* Most important line 
		adding 1.0 to seamlessly fit the distorted (scaled) portions to the rest of the image (scale 1).
		equation -(cos(PI * r) - 1.0) / 2.0 is an easing function "easeInOutSine", 
		which controls the change of scaling at every point along the lens radius */
		float rn = 1.0/(1.0 + (bulge_scale - 1.0) * -(cos(PI * r) - 1.0) / 2.0);
		
		/* Trig functions set the direction based on the angle (a),
		d_len is scaled, based on the new ratio (rn),
		add all that to lens center coordinates
		convert back to Cartesian coordinates */
		d.x = rn*d_len*cos(a); 
		d.y = rn*d_len*sin(a);
		uv = (lens_center_pos + d);
	}
	
	// Convert back to normalized coordinates
	uv = float2(uv.x / texture_width, uv.y / texture_height);
	
	// Draw border of the lens for debug purposes
	if (bulge_show_lens_border) {
		if (d_len > lens_radius - 3.0 && d_len < lens_radius) {
			// Opacity 0.7 (70%)
			float4 lens_border_color = lerp(image.Sample(def_sampler, uv), float4(1.0,0.0,0.0,1.0), 0.7);
			return lens_border_color;
		}
	}
	
	// Draw center of the lens for debug purposes
	if (bulge_show_lens_center) {
		if (d_len < 3.0) {
			return float4(1.0,0.0,0.0,1.0);
		}
	}
	
	return image.Sample(def_sampler, uv);
}

technique Draw
{
	pass
	{
		vertex_shader = VSDefault(vert_in);
		pixel_shader  = PSDrawBare(vert_in);
	}
}
]]
