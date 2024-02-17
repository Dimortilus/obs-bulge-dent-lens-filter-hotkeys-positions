## Description
Shader-based Bulge/Dent lens filter for OBS.<br/>
Lens position can be changed via hotkeys.<br/>

## Settings
<ul>
<li>For "Bulge" effect, set "Scale to a value greater than 1</li>
<li>For "Dent" effect, set "Scale" to a value less than 1</li>
<li>The lens radius is a normalized value, based on side length.<br/>
Which side it is, depends on the "Base the radius on length of the shorter side" checkbox, which is ON by default.<br/>
When it's ON, it effectively means that the lens, when positioned in the middle of the source, is inscribed in the source rectangle at "max" radius of 0.5<br/> 
(well, technically, the maximum radius value is indeed 0.5, because it's 1/2 of the side, but it can be set to 1.0 so that it stretches outside the image, if needs be).</li>  
<li>"Show lens border" and "Show lens center" checkmarks (OFF by default) help in positioning the lens more precisely.</li>
</ul>

The filter, upon being added to a source, registers hotkeys for three positions (center, top, bottom right), the position changes upon hotkey press. 
For the hotkeys to work, they need to be set to the desired key combinations in OBS settings. 
[File -> Settings -> Hotkeys]

## How to install
<ol>
<li>Copy the "obs-bulge-dent-lens-filter-hotkeys-positions.lua" script file to the desired location.<br/>
It is safe to ignore the "bulge-dent-lens-filter.effect" shader file, its contents are already embedded into the lua script.</li>
<li>Load the script in OBS via [Tools -> Scripts -> "+" button]</li>
<li>Add the filter to the desired source. The filter's default name is "Bulge/Dent lens filter (with hotkeys for positions)". The name can be edited if needed, in the lua script at the top there's the setting
<code>TEXT_FILTER_NAME = 'Bulge/Dent lens filter (with hotkeys for positions)'</code></li>
</ol>

### About hotkey-activated positions:
Play around with the filter and see which values  of "Scale", "Lens center X" and "Lens center Y" you want for each lens position, then replace the <code>bulge_scale</code>, <code>bulge_radius</code>, <code>bulge_center_x_norm</code> and <code>bulge_center_y_norm</code> values in the <code>filter.bulge_positions</code> table of the script with those values of yours.</br>
After being done with editing the script file, <strong>don't forget to save the changes!!!</strong>

## Making the changes to the script come into action
<p><strong>Updating the script via the dedicated button in the scripts window is not well tested</strong>, so instead it might be preferrable to just remove the filter from the source, then delete the script from OBS  [Tools -> Scripts -> "trash bin" button]. </br> 
Optionally restart OBS (never hurts to do that), then add the script and the filter back in as usual.</br>

<strong>Important!!!</strong> after setting the hotkeys in the OBS settings, upon pressing a hotkey combination <strong>the change of the current fisheye filter settings won't be reflected in the UI</strong>.</p>
However, the actual settings themselves shall change successfully, regardless of the state of the UI, and <strong>that change will be reflected in the preview window</strong>. 

## Using "Bulge" and "Dent" as separate filters
To have more than one filter working at the same time, so that it would be possible able to toggle them on and off as separate filters, here is how to do it:
<ol>
<li>Make two copies of the lua script file, give the copies unique names, e.g. replace the "bulge-dent" part with "bulge" and "dent" respectively</li>
<li>Inside the scripts edit the <code>TEXT_FILTER_NAME</code> variable so that its value would be unique for each script, e.g. replace the "Bulge/Dent" part with "Bulge" and "Dent" respectively (so that it would be possible to tell them apart in the "Filters" window)</li>
<li>Edit the source_info.id variable in a unique way too, e.g. 'filter-bulge-lens' and 'filter-dent-lens' respectively</li>  
</ol>

The <code>'htk_name'</code> variables could also be renamed uniquely too, so that the "Hotkeys" window won't have 2 of the same sets of hotkey names, but it can be safely ignored, as it is possible to just assign both sets of hotkeys the same combinations.
The OBS is going to complain (with a little yellow "alert" sign next to the hotkey combinations in the hotkey settings window) about them being assigned the same combinations, but it should still work perfectly fine.
