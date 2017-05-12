require 'cairo'

COLOR_FONT_R = 0.933
COLOR_FONT_G = 0.905
COLOR_FONT_B = 0.894

COLOR_PRIMARY_R = 0.784
COLOR_PRIMARY_G = 0.431
COLOR_PRIMARY_B = 0.267

COLOR_SECONDARY_R = 0.4
COLOR_SECONDARY_G = 0.612
COLOR_SECONDARY_B = 0.4

function init_cairo()
  if conky_window == nil then
    return false
  end

  cs = cairo_xlib_surface_create(
    conky_window.display,
    conky_window.drawable,
    conky_window.visual,
    conky_window.width,
    conky_window.height)

  cr = cairo_create(cs)

  font = "Mono"

  cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  return true
end

function conky_main()
  if (not init_cairo()) then
    return
  end

  -- TIME
  cairo_set_font_size(cr, 130)
  cairo_move_to(cr, 644, 230)
  cairo_show_text(cr, conky_parse("${time %H:%M}"))
  cairo_stroke(cr)
  
  -- DATE
  cairo_set_font_size(cr, 27)
  cairo_move_to(cr, 664, 280)
  local time_str = string.format('%-12s', conky_parse("${time %A,}"))..conky_parse("${time %d.%m.%Y}")
  cairo_show_text(cr, time_str)
  cairo_stroke(cr)
  
  -- CPU GRAPH
  -- Non-linear (sqrt instead) so graph area approximatly matches usage
  
  local cx,cy = 240,585
  local radius = 110
  local half_radius = 0.05 + radius * math.sqrt(0.5) * 0.95

  cairo_set_source_rgba(cr, COLOR_PRIMARY_R, COLOR_PRIMARY_G, COLOR_PRIMARY_B, 1)
  local cpu1 = 0.05 + math.sqrt(tonumber(conky_parse("${cpu cpu1}")) / 100.0) * 0.95
  local cpu2 = 0.05 + math.sqrt(tonumber(conky_parse("${cpu cpu2}")) / 100.0) * 0.95
  local cpu3 = 0.05 + math.sqrt(tonumber(conky_parse("${cpu cpu3}")) / 100.0) * 0.95
  local cpu4 = 0.05 + math.sqrt(tonumber(conky_parse("${cpu cpu4}")) / 100.0) * 0.95
  cairo_set_line_width(cr, 1)
  cairo_move_to(cr, cx + radius * cpu1, cy)
  cairo_line_to(cr, cx, cy + radius * cpu2)
  cairo_line_to(cr, cx - radius * cpu3, cy)
  cairo_line_to(cr, cx, cy - radius * cpu4)
  cairo_fill(cr)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B,0.4)
  cairo_set_line_width(cr, 1)
  cairo_move_to(cr, cx + radius, cy)
  cairo_rel_line_to(cr, -radius, radius)
  cairo_rel_line_to(cr, -radius, -radius)
  cairo_rel_line_to(cr, radius, -radius)
  cairo_rel_line_to(cr, radius, radius)
  cairo_stroke(cr)

  cairo_move_to(cr, cx + half_radius, cy)
  cairo_rel_line_to(cr, -half_radius, half_radius)
  cairo_rel_line_to(cr, -half_radius, -half_radius)
  cairo_rel_line_to(cr, half_radius, -half_radius)
  cairo_rel_line_to(cr, half_radius, half_radius)
  cairo_stroke(cr)

  cairo_move_to(cr, cx + radius, cy)
  cairo_rel_line_to(cr, - 2*radius, 0)
  cairo_stroke(cr)

  cairo_move_to(cr, cx, cy + radius)
  cairo_rel_line_to(cr, 0, - 2*radius)
  cairo_stroke(cr)


  -- PROCESSES
  
  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  cairo_set_font_size(cr, 12)
  local ps_str = conky_parse("${exec ps -Ao comm,pcpu,%mem  --sort=-pcpu | head -n 15}")
  local processes = {}
  for line in string.gmatch(ps_str, '([^\n]+)') do
    table.insert(processes, line)
  end
  for line = 1,table.getn(processes) do
    cairo_move_to(cr, 360, 470 + line * 15)
    cairo_show_text(cr, processes[line])
  end
  cairo_stroke(cr)

  
  -- MEMORY
  
  local memperc = tonumber(conky_parse("$memperc"))

  local row,col = 0,0
  local rows = 5
  local perc = 0.0
  local perc_incr = 100.0 / 40.0
  local cx,cy = 720,510
  local grid_width = 36
  for i = 1,40 do
    if (memperc > perc) then
      cairo_set_source_rgba(cr, COLOR_PRIMARY_R, COLOR_PRIMARY_G, COLOR_PRIMARY_B, 1)
      cairo_arc(cr, cx, cy, grid_width / 2.7, 0, 2*math.pi)
    else
      cairo_set_source_rgba(cr, COLOR_SECONDARY_R, COLOR_SECONDARY_G, COLOR_SECONDARY_B, 1)
      cairo_arc(cr, cx, cy, grid_width / 8.0, 0, 2*math.pi)
    end
    cairo_fill(cr)

    row = row + 1
    cy = cy + grid_width
    if (row >= rows) then
      row = row - rows
      cy = cy - rows*grid_width
      col = col + 1
      cx = cx + grid_width
    end
    perc = perc + perc_incr
  end

end

-- FILE SYSTEM

function conky_fs_main()
  if (not init_cairo()) then
    return
  end

  local offset = 1160
  local gap = 90

  draw_volume("     /", tonumber(conky_parse("${fs_used_perc /}")) , offset)
  draw_volume("   media", tonumber(conky_parse("${fs_used_perc /media/hdd/}")) , offset + gap)

  local dropbox_perc = 0
  local file = io.popen("python ~/.conky/dropbox/get_quota.py")
  for line in file:lines() do
    dropbox_perc = tonumber(line)
  end
  file:close()
  draw_volume("  dropbox", dropbox_perc, offset + 2*gap)

  local drive_perc = 0
  local file = io.popen("python ~/.conky/drive/get_quota.py")
  for line in file:lines() do
    drive_perc = tonumber(line)
  end
  file:close()
  draw_volume("   drive", drive_perc , offset + 3*gap)
  

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  cr = nil
end

function draw_volume(name, used, cx)
  local cy = 646
  local width,height = 65,15
  local volume_height = 140
  local filled_height = volume_height * used / 100
  local line_width = 5

  cairo_set_line_width(cr, line_width)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  draw_ellipse(cx, cy, width, height);
  cairo_stroke(cr)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  draw_ellipse(cx, cy, width, height);
  cairo_stroke(cr)

  cairo_set_line_width(cr, line_width / 2)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  cairo_move_to(cr, cx - line_width/2 + 1, cy + height/2)
  cairo_rel_line_to(cr, 0, -volume_height)
  cairo_stroke(cr)

  cairo_move_to(cr, cx + width + line_width/2 - 1, cy + height/2)
  cairo_rel_line_to(cr, 0, -volume_height)
  cairo_stroke(cr)

  cairo_set_line_width(cr, line_width)

  cairo_set_source_rgba(cr, COLOR_SECONDARY_R, COLOR_SECONDARY_G, COLOR_SECONDARY_B, 1)
  cairo_rectangle(cr, cx, cy+height/2, width, -filled_height)
  cairo_fill(cr)
  
  cairo_set_source_rgba(cr, COLOR_SECONDARY_R, COLOR_SECONDARY_G, COLOR_SECONDARY_B, 1)
  draw_ellipse(cx, cy, width, height);
  cairo_fill(cr)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  draw_ellipse(cx, cy-filled_height, width, height);
  cairo_stroke(cr)

  cairo_set_source_rgba(cr, COLOR_SECONDARY_R, COLOR_SECONDARY_G, COLOR_SECONDARY_B, 1)
  draw_ellipse(cx, cy-filled_height, width, height);
  cairo_fill(cr)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  draw_ellipse(cx, cy-volume_height, width, height);
  cairo_stroke(cr)

  cairo_set_source_rgba(cr, COLOR_PRIMARY_R, COLOR_PRIMARY_G, COLOR_PRIMARY_B, 1)
  draw_ellipse(cx, cy-volume_height, width, height);
  cairo_fill(cr)

  cairo_set_source_rgba(cr, COLOR_FONT_R, COLOR_FONT_G, COLOR_FONT_B, 1)
  cairo_move_to(cr, cx, cy + 40)
  cairo_show_text(cr, name)
  cairo_stroke(cr)
end

function draw_ellipse(cx, cy, width, height)
  cairo_save (cr);
  cairo_translate (cr, cx + width / 2., cy + height / 2.);
  cairo_scale (cr, width / 2., height / 2.);

  cairo_arc (cr, 0., 0., 1., 0., 2 * math.pi);
  cairo_restore (cr);
end
