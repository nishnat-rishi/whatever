local u = require('lib.utility')
local anim = require('lib.anim')
local lume = require('lib.lume')
local timer = require('lib.timer')
local vec2d = require('lib.vec2d')
local id = require('lib.id')
local data_handler = require('lib.data-handler')

local font = u.setDigitalFont()
local theme = {
  font = font,
  font_color = {255, 255, 255},
}

local list = require('lib.list-simple')
local list_2 = require('lib.list-simple-2')
local list_reminder = require('lib.list-simple-reminder')
local list_toggle = require('lib.list-simple-toggle')
local list_toggle_2 = require('lib.list-simple-toggle-2')

local typer = require('lib.typer')
local time_setter = require('lib.time-setter')
local date_setter = require('lib.date-setter')
local progress_bar = require('lib.progress-bar')
local clock = require('lib.clock')
local summary_pane = require('lib.summary-pane')

local reminder = require('lib.reminder')

list:init{theme = theme}
list_2:init{theme = theme}
list_reminder:init{theme = theme}
list_toggle:init{theme = theme}
list_toggle_2:init{theme = theme}

typer:init{theme = theme, timer = timer}
time_setter:init{theme = theme}
date_setter:init{theme = theme}
progress_bar:init{anim = anim, theme = theme}
clock:init{theme = theme}
summary_pane:init{theme = theme}

reminder:init{id = id}

local origin, cursor,

program, layout, pages, hidden, current_page, data,

sounds,

weekdays, months, years_translator

weekdays = {
  [0] = 'Sunday',
  [1] = 'Monday',
  [2] = 'Tuesday',
  [3] = 'Wednesday',
  [4] = 'Thursday',
  [5] = 'Friday',
  [6] = 'Saturday',
}

months = {
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
}

years_translator = {}

for i = 1, 200 do
  years_translator[i] = 2021 + i - 1
end

local skip_translate = {
  [1] = nil,
  [2] = true,
  [3] = false
}

local toggle_translate = {
  [true] = true,
  [false] = nil
}

local function transition_to(page)
  anim:move{
    program,
    to = page,
    duration = 0.25,
    fn = anim.fn.SIN
  }
  current_page = page
end

local function reset_edit_data()
  local addendum = data.edit.constraints.date.addendum

  local t = os.date('*t', data.today)
  addendum.skip_ref.day = t.day
  addendum.skip_ref.month = t.month
  addendum.skip_ref.year = t.year

  program.constraints.date.skip_ref.focus.current = 1
  program.constraints.date.skip_ref:update_message()

  for k, v in pairs(addendum) do
    if k ~= 'skip_ref' then
      addendum[k] = true
    end
  end

  local lists = data.edit.constraints.date.lists

  for k, l in pairs(lists) do
    for n, v in pairs(l) do
      l[n] = nil
    end
  end


  data.edit.time.sec = 0
  data.edit.time.min = 0
  data.edit.time.hour = 0

  data.edit.message = ''
  program.typer:update_message(data.edit.message)

  for k in pairs(data.edit.time) do
    data.edit.time[k] = 0
  end
  program.time_setter.focus.current = 1
  program.time_setter:update_message()

  data.edit.id = nil
  data.edit.created_on = nil


  -- reset UI

  for _, l in pairs(program.constraints.date.lists) do
    l:reset()
  end

  for _, l in pairs(program.constraints.date.o_lists) do
    l.offset = 0
  end

  for _, b in pairs(program.constraints.date.buttons) do
    b.state = true
  end

  -- since o_lists are connected to data..., they will be cleared.

end

local function fill_todays_reminders()
  data.todays_reminders = lume.filter(data.reminders,
    function(r)
      return reminder:is_on_date(r, os.date('*t', data.today))
    end,
    true
  )

  local now = data.now
  -- interplay between 'upcoming' and 'pending'
  local item_time = os.date('*t', data.now)
  for k, r in pairs(data.todays_reminders) do
    item_time.hour, item_time.min, item_time.sec = r.time.hour, r.time.min, r.time.sec
    local _
    _, data.remainder_times[k] = os.difftime(os.time(item_time), now)
  end
end

local function dayify(time)
  local d = os.date('*t', time)
  d.hour, d.min, d.sec = 0, 0, 0
  return os.time(d)
end

local function save_progress()
  local yesterday = os.date('*t', dayify(data.today - (12 * 60 * 60)))

  local raw_p = data_handler:progress_decompose(
    lume.filter(data.reminders, function(item)
        return item.state == reminder.states.completed
      end,
      true
    ),
    yesterday
  )
  local f = io.open('assets/data/progress', 'a')
  f:write(raw_p, '\n')
  f:close()
end

local function reset_reminders()

  save_progress()

  for _, r in pairs(data.reminders) do
    r.state = reminder.states.upcoming
  end
end

local function update_todays_reminders()

  if data.today + (24 * 60 * 60) < data.now then
    data.today = dayify(data.now)

    fill_todays_reminders()
    reset_reminders()

    sounds.pling_midnight:stop()
    sounds.pling_midnight:play()
  end

  local now = data.now
  -- interplay between 'upcoming' and 'pending'
  local item_time = os.date('*t', data.now)
  local completed, total = 0, 0
  for k, r in pairs(data.todays_reminders) do
    item_time.hour, item_time.min, item_time.sec = r.time.hour, r.time.min, r.time.sec
    data.remainder_times[k] = os.difftime(os.time(item_time), now)
    if r.state == reminder.states.upcoming and data.remainder_times[k] < 0 then
      data.todays_reminders[k].state = reminder.states.pending
      sounds.pling:stop()
      sounds.pling:play()
    end
    if r.state == reminder.states.completed then
      completed = completed + 1
    end
    total = total + 1
  end

  for k, r in pairs(data.reminders) do
    if not data.todays_reminders[k] then
      if r.state == reminder.states.ongoing then
        total = total + 1
      elseif r.state == reminder.states.completed then
        completed, total = completed + 1, total + 1
      end
    end
  end

  data.completion_rate = total == 0 and 0 or completed / total
end

local function create_reminder()
  local polarities = program.constraints.date.buttons
  local addendum = data.edit.constraints.date.addendum

  for k in pairs(addendum) do
    if k ~= 'skip_ref' then
      addendum[k] = polarities[k].state
    end
  end

  -- data...skip_ref is already connected to date_setter.
  -- data..time is already connceted to time_setter.
  -- data..message is already connected to typer.

  if data.edit.message == '' then
    data.edit.message = '<Reminder>'
  end

  local r = reminder:create(data.edit)

  sounds.pling_made:stop()
  sounds.pling_made:play()

  data.reminders[r.id] = r
  fill_todays_reminders()

  reset_edit_data()
end

local function fill_edit_fields()
  local r = data.selected_reminder
  
  local lists = program.constraints.date.lists
  local p_buttons = program.constraints.date.buttons
  local skip_ref = program.constraints.date.skip_ref

  program.typer:update_message(r.message)
  -- fixes data.edit.message as well

  for k in pairs(data.edit.time) do
    data.edit.time[k] = r.time[k]
  end
  program.time_setter:update_message()

  data.edit.id = r.id
  data.edit.created_on = r.created_on

  -- addendum
  for k, s in pairs(r.constraints.date.addendum) do
    if k ~= 'skip_ref' then
      p_buttons[k].state = s
      data.edit.constraints.date.addendum[k] = s
    end
  end

  -- skip_ref
  for k, n in pairs(r.constraints.date.addendum.skip_ref) do
    skip_ref.data[k] = n
    -- fixes data.edit... as well
  end
  skip_ref:update_message()

  -- input lists
  for k, l in pairs(lists) do
    if k == 'years' then
      for n, s in pairs(r.constraints.date.lists[k]) do
        l.items[n - 2020] = s
      end
    elseif k == 'skipdays' then
      for n, s in pairs(r.constraints.date.lists[k]) do
        l.items[n] = s and 2 or 3
      end
    else
      for n, s in pairs(r.constraints.date.lists[k]) do
        l.items[n] = s
      end
    end
  end

  -- output lists
  for k, l in pairs(data.edit.constraints.date.lists) do
    for n, s in pairs(r.constraints.date.lists[k]) do
      l[n] = s
    end
  end
  
end

local function prev_page()
  if current_page == pages.edit[1] or current_page == pages.all then
    return pages.home
  elseif current_page == pages.edit[2] then
    return pages.edit[1]
  elseif current_page == pages.edit[3] then
    return pages.edit[2]
  end
end

local function next_page()
  if current_page == pages.home then
    return pages.edit[1]
  elseif current_page == pages.edit[1] then
    return pages.edit[2]
  elseif current_page == pages.edit[2] then
    return pages.edit[3]
  end
end

local function view_summary(r)

  data.selected_reminder = r

  -- along with this, move in 2 buttons as well.
  if not r then
    anim:move{
      id = 'pane',
      program,
      to = pages.summary.hide,
      fn = anim.fn.SIN,
      duration = 0.25
    }
    if current_page == pages.home then
      anim:move{
        program.buttons.restore,
        to = pages.home.buttons.restore,
        fn = anim.fn.SIN,
        duration = 0.25
      }
    end
  else
    program.summary_pane:update_reminder(r)
    if r.state == reminder.states.upcoming or
    r.state == reminder.states.pending then
      anim:move{
        id = 'pane',
        program,
        to = pages.summary.show.latent,
        fn = anim.fn.SIN,
        duration = 0.25
      }
    elseif r.state == reminder.states.ongoing then
      anim:move{
        id = 'pane',
        program,
        to = pages.summary.show.kinetic,
        fn = anim.fn.SIN,
        duration = 0.25
      }
    else
      anim:move{
        id = 'pane',
        program,
        to = pages.summary.show.archival,
        fn = anim.fn.SIN,
        duration = 0.25
      }
    end
  end
end

local function view_summary_all(r)

  data.selected_reminder = r

  -- along with this, move in 2 buttons as well.
  if not r then
    anim:move{
      id = 'pane',
      program,
      to = pages.summary.all.hide,
      fn = anim.fn.SIN,
      duration = 0.25
    }
    if current_page == pages.all then
      anim:move{
        program.buttons.restore,
        to = pages.all.buttons.restore,
        fn = anim.fn.SIN,
        duration = 0.25
      }
    end
  else
    program.summary_pane:update_reminder(r)
    anim:move{
      id = 'pane',
      program,
      to = pages.summary.all.show,
      fn = anim.fn.SIN,
      duration = 0.25
    }
  end
end

local function view_feedback(text)
  program.texts.feedback.text = text
  anim:move{
    program.texts.feedback,
    to = pages.feedback.show,
    fn = anim.fn.SIN,
    duration = 0.25,
    on_end = function()
      timer:create{
        id = 'feedback-fade',
        duration = 4,
        on_end = function()
          anim:move{
            program.texts.feedback,
            to = pages.home.texts.feedback,
            fn = anim.fn.SIN,
            duration = 0.25
          }
        end
      }
    end
  }
end

local function partial_delete()
  local r_id = data.selected_reminder.id
  data.to_delete[r_id] = data.selected_reminder
  table.insert(data.to_delete_ids, r_id)

  data.reminders[r_id] = nil
  data.todays_reminders[r_id] = nil
  data.selected_reminder = nil

  program.buttons.restore.state = true
end

local function full_delete()
  for i, d_id in ipairs(data.to_delete_ids) do
    id.repository[d_id] = nil
  end
end

local function light_save_ops()
  local f = io.open('assets/data/reminders', 'w')
  for id_val, r in pairs(data.reminders) do
    f:write(data_handler:decompose(r), '\n')
  end
  f:close()

  local f3 = io.open('assets/data/last-saved', 'w')
  f3:write(tostring(os.time()))
  f3:close()

  local f4 = io.open('assets/data/archive', 'a')
  for _, r in pairs(data.to_archive) do
    f4:write(data_handler:archive(r), '\n')
  end
  f4:close()
end

local function save_ops()
  full_delete()
  light_save_ops()
end

local function load_ops()
  data.reminders = {}
  id.repository = {}
  for raw_r in io.lines('assets/data/reminders') do
    local r = data_handler:recompose(raw_r)
    data.reminders[r.id] = r
    id.repository[r.id] = true
  end

  local f = io.open('assets/data/last-saved', 'r')
  local raw_data_3 = f:read("*a")
  data.last_saved = tonumber(raw_data_3)
  f:close()
end

local function go_back()
  if current_page == pages.home then
    if data.last_clicked_list then
      data.last_clicked_list.active = nil
      data.selected_reminder = nil
    end
    view_summary()
  elseif current_page == pages.all then
    data.selected_reminder = nil
    data.selected_reminder_key = nil
    view_summary_all()
  elseif current_page == pages.edit[1] then
    reset_edit_data()
  end

  if current_page ~= pages.home then
    transition_to(prev_page())
  end
end

local function set_fields(params)
  local i_lists, o_lists =
    program.constraints.date.lists,
    data.edit.constraints.date.lists


  -- both lists
  for k, l in pairs(params) do
    if k == 'years' then
      for n, s in pairs(l) do
        i_lists[k].items[n - 2020] = s
        o_lists[k][n] = s
      end
    elseif k == 'skipdays' then
      for n, s in pairs(l) do
        i_lists[k].items[n] = s and 2 or 3
        o_lists[k][n] = s
      end
    else
      for n, s in pairs(l) do
        i_lists[k].items[n] = s
        o_lists[k][n] = s
      end
    end
  end
end

local function undo_delete()
  local restore_id = table.remove(data.to_delete_ids)
  data.reminders[restore_id] = data.to_delete[restore_id]
  data.to_delete[restore_id] = nil

  fill_todays_reminders()
  data.selected_reminder = data.reminders[restore_id]

  program.buttons.restore.state = #data.to_delete_ids > 0
end

local function undo_archive()
  undo_delete()
  data.to_archive[data.selected_reminder.id] = nil
end

local function undo_purge() -- either deletion or archive
  local last_id = data.to_delete_ids[#data.to_delete_ids]
  if data.to_archive[last_id] then
    undo_archive()
  else
    undo_delete()
  end

  view_feedback('Restored!')
  sounds.pling_restore:stop()
  sounds.pling_restore:play()
end

local function on_delete()
  partial_delete()

  sounds.pling_down:stop()
  sounds.pling_down:play()
end

local function on_archive()
  local r_id = data.selected_reminder.id
  data.to_archive[r_id] = data.selected_reminder
  partial_delete()

  sounds.pling_rest:stop()
  sounds.pling_rest:play()
end

local function on_doing()
  data.selected_reminder.state = reminder.states.ongoing
  sounds.pling_do:stop()
  sounds.pling_do:play()
end

local function on_finish()
  data.selected_reminder.state = reminder.states.completed
  sounds.pling_up:stop()
  sounds.pling_up:play()
end

local function on_reset()
  data.selected_reminder.state = reminder.states.upcoming
  sounds.pling_reset:stop()
  sounds.pling_reset:play()
end

function love.quit()
  save_ops()
end

function love.load()
  origin = {x = 100, y = 100}

  cursor = vec2d()

  layout = {
    border = 10,
    window = {
      x = love.graphics.getWidth(),
      y = love.graphics.getHeight()
    },
    button = {
      x = 90, y = 40
    },
    list_margin = 5,
    list_text_margin = 10,
    list = {
      x = 250, y = 195
    },
    list_all = {
      x = 400, y = 490
    },
    list_item_all = {
      x = 390, y = 30
    },
    text = {
      x = 250,  y = 30
    },
    text_all = {
      x = 400, y = 30
    },
    constraint_list = {
      x = 130,
      y = 160
    },
    constraint_o_list = {
      x = 130,
      y = 200
    },
    constraint_button = {
      x = 130,
      y = 30
    },
    summary_pane = {
      x = 240,
      y = 400
    },
    progress_bar = {
      x = 510,
      y = 40
    },
  }

  layout.list_item = {
    x = layout.list.x - 2 * layout.list_margin, y = 30
  }

  layout.list_item_all = {
    x = layout.list_all.x - 2 * layout.list_margin, y = 30
  }

  layout.clock = {
    x = layout.progress_bar.x - (layout.button.x + layout.border),
    y = 40
  }

  layout.constraint_x = 
    layout.border + (
      (layout.window.x - 2 * layout.border) -
      (5 * layout.constraint_list.x + 4 * layout.border)
    ) / 2

  sounds = {
    pling = love.audio.newSource('assets/sounds/pling-2.wav', 'static'),
    pling_down = love.audio.newSource('assets/sounds/pling-back-2.wav', 'static'),
    pling_up = love.audio.newSource('assets/sounds/pling-up.wav', 'static'),
    pling_do = love.audio.newSource('assets/sounds/pling-do.wav', 'static'),
    pling_made = love.audio.newSource('assets/sounds/pling-made.wav', 'static'),
    pling_rest = love.audio.newSource('assets/sounds/pling-rest.wav', 'static'),
    pling_reset = love.audio.newSource('assets/sounds/pling-reset.wav', 'static'),
    pling_save = love.audio.newSource('assets/sounds/pling-save.wav', 'static'),
    pling_midnight = love.audio.newSource('assets/sounds/pling-midnight.wav', 'static'),
    pling_restore = love.audio.newSource('assets/sounds/pling-restore.wav', 'static'),
  }

  data = {
    reminders = nil,
    todays_reminders = nil,
    last_saved = nil,
    remainder_times = {},
    today = nil,
    now = os.time(),

    last_clicked_list = nil,
    selected_reminder = nil,
    completion_rate = nil,

    to_archive = {},

    to_delete = {},
    to_delete_ids = {}, -- to maintain order of deletion

    edit = {
      message = '',

      id = nil,
      created_on = nil,

      time = {
        hour = 0,
        min = 0,
        sec = 0
      },
      constraints = {
        date = {
          addendum = {
            days = true,
            months = true,
            years = true,
            weekdays = true,
            skip_ref = {
              day = 14,
              month = 9,
              year = 2021,
              hour = 0,
              min = 0,
              sec = 0
            },
          },
          lists = {
            days = {},
            months = {},
            years = {},
            weekdays = {},
            skipdays = {},
          }
        }
      }
    }
  }

  data.today = dayify(data.now)
  local sr = data.edit.constraints.date.addendum.skip_ref
  local t = os.date('*t', data.today)
  sr.day, sr.month, sr.year = t.day, t.month, t.year
 
  load_ops()

  fill_todays_reminders()
  update_todays_reminders()

  local diff_days = u.days_diff_t(data.today, dayify(data.last_saved))
  if diff_days > 0 then -- it's a new day, all reminders should be reset
    reset_reminders()
  end

  hidden = {
    buttons = {
      add = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.window.y - (layout.button.y + layout.border)
        }
      },
      all = {
        pos = {
          x = layout.window.x - 2 * (layout.button.x + layout.border),
          y = layout.window.y + layout.border
        }
      },
      next = {
        pos = {
          x = layout.window.x - (layout.button.x + 2 * layout.border),
          y = layout.window.y + layout.border
        }
      },
      done = {
        pos = {
          x = layout.window.x - (layout.button.x + 2 * layout.border),
          y = layout.window.y + layout.border
        }
      },
      skipdays = {
        pos = {
          x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border),
          y = layout.window.y + 100 + (layout.border + layout.constraint_list.y)
        }
      },
      back = {
        pos = {
          x = layout.window.x - (layout.button.x + layout.border),
          y = layout.window.y + layout.border
        }
      },
      today = {
        pos = {
          x = 2 * layout.border,
          y = layout.window.y + layout.border
        }
      },
      save = {
        pos = {
          x = layout.window.x - 2 * (layout.button.x + layout.border),
          y = layout.window.y + layout.border,
        }
      },

      doing = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
        }
      },
      finish = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
        }
      },

      edit = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
        }
      },
      delete = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
        }
      },
      archive = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
        }
      },

      reset = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
        }
      },
      restore = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.window.y - 2 * (layout.button.y + layout.border)
        }
      }
    },
    lists = {
      pending = {
        pos = {
          x = - (layout.list.x + layout.border),
          y = 2 * layout.border + layout.text.y
        }
      },
      upcoming = {
        pos = {
          x = - (layout.list.x + layout.border),
          y = 2 * (2 * layout.border + layout.text.y) + layout.list.y
        }
      },
      ongoing = {
        pos = {
          x = layout.list.x + 2 * layout.border,
          y = - (layout.list.y + layout.border)
        }
      },
      completed = {
        pos = {
          x = layout.list.x + 2 * layout.border,
          y = layout.window.y + 2 * layout.border + layout.text.y
        }
      },
      all = {
        pos = {
          x = - (layout.list_all.x + layout.border),
          y = 2 * layout.border + layout.text.y
        }
      }
    },
    constraints = {
      date = {
        lists = {
          days = {
            pos = {
              x = layout.constraint_x,
              y = layout.window.y + 100
            }
          },
          months = {
            pos = {
              x = layout.constraint_x + 1 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100
            }
          },
          years = {
            pos = {
              x = layout.constraint_x + 2 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100
            }
          },
          weekdays = {
            pos = {
              x = layout.constraint_x + 3 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100
            }
          },
          skipdays = {
            pos = {
              x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100
            }
          }
        },
        buttons = {
          days = {
            pos = {
              x = layout.constraint_x,
              y = layout.window.y + 100 + (layout.border + layout.constraint_list.y)
            }
          },
          months = {
            pos = {
              x = layout.constraint_x + 1 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (layout.border + layout.constraint_list.y)
            }
          },
          years = {
            pos = {
              x = layout.constraint_x + 2 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (layout.border + layout.constraint_list.y)
            }
          },
          weekdays = {
            pos = {
              x = layout.constraint_x + 3 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (layout.border + layout.constraint_list.y)
            }
          }
        },
        o_lists = {
          days = {
            pos = {
              x = layout.constraint_x,
              y = layout.window.y + 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
            }
          },
          months = {
            pos = {
              x = layout.constraint_x + 1 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
            }
          },
          years = {
            pos = {
              x = layout.constraint_x + 2 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
            }
          },
          weekdays = {
            pos = {
              x = layout.constraint_x + 3 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
            }
          },
          skipdays = {
            pos = {
              x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border),
              y = layout.window.y + 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
            }
          }
        },
        skip_ref = {
          pos = {
            x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border) + (layout.constraint_button.x - font:getWidth('xx/xx/xxxx')) / 2,
            y = layout.window.y + 100 + (layout.border + layout.constraint_list.y) + (layout.constraint_button.y - font:getHeight()) / 2
          }
        }
      }
    },
    texts = {
      pending = {
        pos = {
          x = - (layout.list.x + layout.border),
          y = layout.border,
        },
      },
      upcoming = {
        pos = {
          x = - (layout.list.x + layout.border),
          y = 3 * layout.border + font:getHeight() + layout.list.y
        }
      },
      ongoing = {
        pos = {
          x = layout.list.x + 2 * layout.border,
          y = -(layout.list.y + font:getHeight() + 3 * layout.border)
        },
      },
      completed = {
        pos = {
          x = layout.list.x + 2 * layout.border,
          y = layout.window.y + layout.border
        }
      },
      all = {
        pos = {
          x = - (layout.list_all.x + layout.border),
          y = layout.border
        }
      },
      summary = {
        pos = {
          x = layout.border,
          y = layout.window.y + layout.border
        }
      },
      constraints = {
        pos = {
          x = layout.border,
          y = layout.window.y + layout.border
        }
      },
      feedback = {
        pos = {
          x = layout.window.x + layout.border,
          y = layout.window.y - 3 * (layout.button.y + layout.border)
        }
      }
    },
    lines = {
      summary_title_line = {
        2 * layout.border,
        layout.window.y + layout.border + layout.text.y,

        layout.window.x - 2 * layout.border,
        layout.window.y + layout.border + layout.text.y,
      }
    },
    summary = {
      pos = {
        x = layout.border,
        y = layout.window.y + layout.border
      }
    },
    typer = {
      pos = {
        x = 2 * layout.border,
        y = 2 * layout.border + layout.text.y + layout.window.y
      }
    },
    progress_bar = {
      pos = {
        x = layout.border,
        y = layout.window.y + layout.border
      }
    },
    clock = {
      pos = {
        x = 3 * layout.border + layout.button.x,
        y = layout.window.y + layout.border,
      },
      dim = layout.clock
    },
    time_setter = {
      pos = {
        x = 2 * layout.border,
        y = layout.window.y + (10 * font:getHeight() + 4 * layout.border + layout.text.y),
      }
    },

    summary_pane = {
      pos = {
        x = layout.window.x + layout.border,
        y = layout.border
      }
    },
  }

  pages = {
    home = {
      buttons = {
        add = {
          pos = {
            x = layout.window.x - (layout.button.x + layout.border),
            y = layout.window.y - (layout.button.y + layout.border)
          }
        },
        next = hidden.buttons.next,
        done = hidden.buttons.done,
        skipdays = hidden.buttons.skipdays,
        all = {
          pos = {
            x = layout.window.x - 2 * (layout.button.x + layout.border),
            y = layout.window.y - (layout.button.y + layout.border)
          }
        },
        back = hidden.buttons.back,
        today = hidden.buttons.today,
        save = hidden.buttons.save,
        restore = {
          pos = {
            x = layout.window.x - (layout.button.x + layout.border),
            y = layout.window.y - 2 * (layout.button.y + layout.border)
          }
        }
      },
      lists = {
        pending = {
          pos = {
            x = layout.border,
            y = 2 * layout.border + layout.text.y
          }
        },
        upcoming = {
          pos = {
            x = layout.border,
            y = 2 * (2 * layout.border + layout.text.y) + layout.list.y
          }
        },
        ongoing = {
          pos = {
            x = 2 * layout.border + layout.list.x,
            y = 2 * layout.border + layout.text.y
          }
        },
        completed = {
          pos = {
            x = 2 * layout.border + layout.list.x,
            y = 2 * (2 * layout.border + layout.text.y) + layout.list.y
          }
        },
        all = hidden.lists.all,
      },
      constraints = hidden.constraints,
      texts = {
        pending = {
          pos = {
            x = layout.border,
            y = layout.border
          },
        },
        upcoming = {
          pos = {
            x = layout.border,
            y = 3 * layout.border + layout.text.y + layout.list.y
          }
        },
        ongoing = {
          pos = {
            x = 2 * layout.border + layout.list.x,
            y = layout.border
          }
        },
        completed = {
          pos = {
            x = 2 * layout.border + layout.list.x,
            y = 3 * layout.border + layout.text.y + layout.list.y
          }
        },
        all = hidden.texts.all,
        summary = hidden.texts.summary,
        constraints = hidden.texts.constraints,
        feedback = hidden.texts.feedback,
      },
      lines = hidden.lines,
      summary = hidden.summary,
      typer = hidden.typer,
      time_setter = hidden.time_setter,
      progress_bar = {
        pos = {
          x = layout.border,
          y = layout.window.y - (layout.progress_bar.y + layout.border)
        }
      },
      clock = {
        pos = {
          x = layout.border,
          y = layout.window.y - 2 * (layout.clock.y + layout.border),
        },
        dim = layout.progress_bar
      }
    },
    edit = {
      { -- 1
        buttons = {
          add = hidden.buttons.add,
          all = hidden.buttons.all,
          next = {
            pos = {
              x = layout.window.x - (layout.button.x + 2 * layout.border),
              y = layout.window.y - (layout.button.y + 2 * layout.border)
            }
          },
          back = {
            pos = {
              x = layout.window.x - (2 * layout.button.x + 3 * layout.border),
              y = layout.window.y - (layout.button.y + 2 * layout.border)
            }
          },
          save = hidden.buttons.save,
          restore = hidden.buttons.restore,
        },
        lists = {
          pending = hidden.lists.pending,
          ongoing = hidden.lists.ongoing,
          upcoming = hidden.lists.upcoming,
          completed = hidden.lists.completed,
          all = {
            pos = {
              x = - (layout.list_all.x + layout.border),
              y = 2 * layout.border + layout.text.y
            }
          }
        },
        texts = {
          pending = hidden.texts.pending,
          upcoming = hidden.texts.upcoming,
          ongoing = hidden.texts.ongoing,
          completed = hidden.texts.completed,
          all = hidden.texts.all,
          summary = {
            pos = {
              x = layout.border,
              y = layout.border
            }
          },
          constraints = hidden.texts.constraints,
          feedback = hidden.texts.feedback,
        },
        lines = {
          summary_title_line = {
            2 * layout.border,
            layout.border + layout.text.y,
  
            layout.window.x - 2 * layout.border,
            layout.border + layout.text.y
          }
        },
        summary = {
          pos = {
            x = layout.border,
            y = layout.border
          }
        },
        typer = {
          pos = {
            x = 2 * layout.border,
            y = 2 * layout.border + layout.text.y
          }
        },
        progress_bar = hidden.progress_bar,
        clock = hidden.clock,
        -- time_setter = hidden.time_setter
      },
      { -- 2
        buttons = {
          next = {
            pos = {
              x = layout.window.x - (layout.button.x + 2 * layout.border),
              y = layout.window.y - (layout.button.y + 2 * layout.border)
            }
          },
          done = hidden.buttons.done,
          skipdays = hidden.buttons.skipdays,
          today = hidden.buttons.today,
        },
        constraints = hidden.constraints,
        texts = {
          summary = {
            pos = {
              x = -layout.window.x
            }
          },
          constraints = {
            pos = {
              y = layout.border
            }
          }
        },
        typer = {
          pos = {
            x = 2 * layout.border,
            y = 2 * layout.border + layout.text.y
          }
        },
        time_setter = {
          pos = {
            x = 2 * layout.border,
            y = (10 * font:getHeight() + 4 * layout.border + layout.text.y),
          }
        },
        clock = {
          pos = {
            x = 3 * layout.border + layout.button.x,
            y = layout.window.y - (layout.clock.y + 2 * layout.border),
          },
          dim = layout.clock
        }
      },
      { -- 3
        buttons = {
          next = hidden.buttons.next,
          done = {
            pos = {
              x = layout.window.x - (layout.button.x + 2 * layout.border),
              y = layout.window.y - (layout.button.y + 2 * layout.border)
            }
          },
          skipdays = {
            pos = {
              x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border),
              y = 100 + (layout.border + layout.constraint_list.y)
            }
          },
          today = {
            pos = {
              x = 2 * layout.border,
              y = layout.window.y - (2 * layout.border + layout.button.y)
            }
          },
        },
        constraints = {
          date = {
            lists = {
              days = {
                pos = {
                  x = layout.constraint_x,
                  y = 100
                }
              },
              months = {
                pos = {
                  x = layout.constraint_x + 1 * (layout.constraint_list.x + layout.border),
                  y = 100
                }
              },
              years = {
                pos = {
                  x = layout.constraint_x + 2 * (layout.constraint_list.x + layout.border),
                  y = 100
                }
              },
              weekdays = {
                pos = {
                  x = layout.constraint_x + 3 * (layout.constraint_list.x + layout.border),
                  y = 100
                }
              },
              skipdays = {
                pos = {
                  x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border),
                  y = 100
                }
              }
            },
            buttons = {
              days = {
                pos = {
                  x = layout.constraint_x,
                  y = 100 + (layout.border + layout.constraint_list.y)
                }
              },
              months = {
                pos = {
                  x = layout.constraint_x + 1 * (layout.constraint_list.x + layout.border),
                  y = 100 + (layout.border + layout.constraint_list.y)
                }
              },
              years = {
                pos = {
                  x = layout.constraint_x + 2 * (layout.constraint_list.x + layout.border),
                  y = 100 + (layout.border + layout.constraint_list.y)
                }
              },
              weekdays = {
                pos = {
                  x = layout.constraint_x + 3 * (layout.constraint_list.x + layout.border),
                  y = 100 + (layout.border + layout.constraint_list.y)
                }
              }
            },
            o_lists = {
              days = {
                pos = {
                  x = layout.constraint_x,
                  y = 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
                }
              },
              months = {
                pos = {
                  x = layout.constraint_x + 1 * (layout.constraint_list.x + layout.border),
                  y = 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
                }
              },
              years = {
                pos = {
                  x = layout.constraint_x + 2 * (layout.constraint_list.x + layout.border),
                  y = 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
                }
              },
              weekdays = {
                pos = {
                  x = layout.constraint_x + 3 * (layout.constraint_list.x + layout.border),
                  y = 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
                }
              },
              skipdays = {
                pos = {
                  x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border),
                  y = 100 + (2 * layout.border + layout.constraint_button.y + layout.constraint_list.y)
                }
              }
            },
            skip_ref = {
              pos = {
                x = layout.constraint_x + 4 * (layout.constraint_list.x + layout.border) + (layout.constraint_button.x - font:getWidth('xx/xx/xxxx')) / 2,
                y = 100 + (layout.border + layout.constraint_list.y) + (layout.constraint_button.y - font:getHeight()) / 2
              }
            }
          },
        },
        typer = hidden.typer,
        time_setter = hidden.time_setter,
        clock = {
          pos = {
            x = 3 * layout.border + layout.button.x,
            y = layout.window.y - (layout.clock.y + 2 * layout.border),
          },
          dim = layout.clock
        }
      }
    },
    all = {
      buttons = {
        add = hidden.buttons.add,

        back = {
          pos = {
            x = layout.window.x - (layout.button.x + layout.border),
            y = layout.window.y - (layout.button.y + layout.border)
          }
        },
        save = {
          pos = {
            x = layout.window.x - 2 * (layout.button.x + layout.border),
            y = layout.window.y - (layout.button.y + layout.border)
          }
        },

        all = hidden.buttons.all,
        restore = {
          pos = {
            x = layout.window.x - (layout.button.x + layout.border),
            y = layout.window.y - 2 * (layout.button.y + layout.border)
          }
        }
      },
      lists = {
        pending = hidden.lists.pending,
        ongoing = hidden.lists.ongoing,
        upcoming = hidden.lists.upcoming,
        completed = hidden.lists.completed,
        all = {
          pos = {
            x = layout.border,
            y = 2 * layout.border + layout.text.y
          }
        }
      },
      texts = {
        pending = hidden.texts.pending,
        ongoing = hidden.texts.ongoing,
        upcoming = hidden.texts.upcoming,
        completed = hidden.texts.completed,
        all = {
          pos = {
            x = layout.border,
            y = layout.border
          }
        }
      },
      progress_bar = hidden.progress_bar,
      clock = {
        pos = {
          x = layout.border,
          y = layout.window.y - (layout.clock.y + layout.border),
        },
        dim = {
          x = layout.list_all.x,
        }
      }
    },
    summary = {
      show = {
        latent = { -- both 'doing' and 'finish'
          summary_pane = {
            pos = {
              x = layout.window.x - (layout.border + layout.summary_pane.x),
              y = layout.border
            }
          },
          buttons = {
            doing = {
              pos = {
                x = layout.window.x - layout.summary_pane.x,
                y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
              }
            },
            finish = {
              pos = {
                x = layout.window.x - (layout.button.x + layout.border),
                y = layout.window.y - 3 * (layout.border + layout.button.y),
              }
            },
            delete = {
              pos = {
                x = layout.window.x - (layout.button.x + layout.border),
                y = layout.window.y - 2 * (layout.border + layout.button.y),
              }
            },
            edit = {
              pos = {
                x = layout.window.x - 2 * (layout.button.x + layout.border),
                y = layout.window.y - 2 * (layout.border + layout.button.y),
              }
            },
            reset = hidden.buttons.reset,
            restore = {
              pos = {
                x = layout.window.x - 2 * (layout.button.x + layout.border),
                y = layout.window.y - 3 * (layout.button.y + layout.border)
              }
            }
          }
        },
        kinetic = { -- only finish
          summary_pane = {
            pos = {
              x = layout.window.x - (layout.border + layout.summary_pane.x),
              y = layout.border
            }
          },
          buttons = {
            doing = hidden.buttons.doing,
            finish = {
              pos = {
                x = layout.window.x - layout.summary_pane.x,
                y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
              }
            },
            delete = {
              pos = {
                x = layout.window.x - (layout.button.x + layout.border),
                y = layout.window.y - 2 * (layout.border + layout.button.y),
              }
            },
            edit = {
              pos = {
                x = layout.window.x - 2 * (layout.button.x + layout.border),
                y = layout.window.y - 2 * (layout.border + layout.button.y),
              }
            },
            reset = {
              pos = {
                x = layout.window.x - (layout.button.x + layout.border),
                y = layout.window.y - 3 * (layout.border + layout.button.y),
              }
            },
            restore = {
              pos = {
                x = layout.window.x - 2 * (layout.button.x + layout.border),
                y = layout.window.y - 3 * (layout.button.y + layout.border)
              }
            }
          }
        },
        archival = { -- only archive
        summary_pane = {
          pos = {
            x = layout.window.x - (layout.border + layout.summary_pane.x),
            y = layout.border
          }
        },
        buttons = {
          doing = {
            pos = {
              x = layout.window.x - (layout.button.x + layout.border),
              y = layout.window.y - 3 * (layout.border + layout.button.y),
            }
          },
          finish = hidden.buttons.finish,
          delete = {
            pos = {
              x = layout.window.x - (layout.button.x + layout.border),
              y = layout.window.y - 2 * (layout.border + layout.button.y),
            }
          },
          edit = {
            pos = {
              x = layout.window.x - 2 * (layout.button.x + layout.border),
              y = layout.window.y - 2 * (layout.border + layout.button.y),
            }
          },
          reset = {
            pos = {
              x = layout.window.x - layout.summary_pane.x,
              y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
            }
          },
          restore = {
            pos = {
              x = layout.window.x - 2 * (layout.button.x + layout.border),
              y = layout.window.y - 3 * (layout.button.y + layout.border)
            }
          }
        }
      }
      },
      hide = {
        summary_pane = hidden.summary_pane,
        buttons = {
          doing = hidden.buttons.doing,
          finish = hidden.buttons.finish,
          delete = hidden.buttons.delete,
          edit = hidden.buttons.edit,
          reset = hidden.buttons.reset,
        }
      },
      all = {
        show = {
          summary_pane = {
            pos = {
              x = layout.window.x - (layout.border + layout.summary_pane.x),
              y = layout.border
            }
          },
          buttons = {
            edit = {
              pos = {
                x = layout.window.x - layout.summary_pane.x,
                y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
              }
            },
            delete = {
              pos = {
                x = layout.window.x - layout.summary_pane.x + (layout.button.x + layout.border),
                y = layout.border + layout.summary_pane.y - (layout.border + layout.button.y)
              }
            },
            archive = {
              pos = {
                x = layout.window.x - (layout.button.x + layout.border),
                y = layout.window.y - 2 * (layout.border + layout.button.y),
              }
            },
            restore = {
              pos = {
                x = layout.window.x - 2 * (layout.button.x + layout.border),
                y = layout.window.y - 2 * (layout.button.y + layout.border)
              }
            },
            doing = {
              pos = {
                x = layout.window.x - 2 * (layout.button.x + layout.border),
                y = layout.window.y - 3 * (layout.border + layout.button.y),
              }
            },
            finish = {
              pos = {
                x = layout.window.x - (layout.button.x + layout.border),
                y = layout.window.y - 3 * (layout.border + layout.button.y),
              }
            }
          }
        },
        hide = {
          summary_pane = hidden.summary_pane,
          buttons = {
            edit = hidden.buttons.edit,
            delete = hidden.buttons.delete,
            archive = hidden.buttons.archive,
            doing = hidden.buttons.doing,
            finish = hidden.buttons.finish,
          }
        },
      }
    },
    feedback = {
      show = {
        pos = {
          x = layout.window.x - 2 * (layout.button.x + layout.border),
          y = layout.window.y - 3 * (layout.button.y + layout.border)
        }
      }
    }
  }

  current_page = pages.home

  program = {
    buttons = {
      add = {
        text = 'Add',
        pos = vec2d.from(pages.home.buttons.add.pos),
        dim = vec2d.from(layout.button)
      },
      next = {
        text = 'Next',
        pos = vec2d.from(pages.home.buttons.next.pos),
        dim = vec2d.from(layout.button)
      },
      done = {
        text = 'Done',
        pos = vec2d.from(pages.home.buttons.done.pos),
        dim = vec2d.from(layout.button)
      },

      doing = {
        text = 'Do This',
        pos = vec2d.from(pages.summary.hide.buttons.doing.pos),
        dim = vec2d.from(layout.button)
      },
      finish = {
        text = 'Finish',
        pos = vec2d.from(pages.summary.hide.buttons.finish.pos),
        dim = vec2d.from(layout.button)
      },
      delete = {
        text = 'Delete',
        pos = vec2d.from(pages.summary.all.hide.buttons.delete.pos),
        dim = vec2d.from(layout.button)
      },

      all = {
        text = 'All',
        pos = vec2d.from(pages.home.buttons.all.pos),
        dim = vec2d.from(layout.button)
      },

      edit = {
        text = 'Edit',
        pos = vec2d.from(pages.summary.all.hide.buttons.edit.pos),
        dim = vec2d.from(layout.button)
      },
      archive = {
        text = 'Archive',
        pos = vec2d.from(pages.summary.all.hide.buttons.archive.pos),
        dim = vec2d.from(layout.button)
      },
      reset = {
        text = 'Reset',
        pos = vec2d.from(pages.summary.hide.buttons.reset.pos),
        dim = vec2d.from(layout.button)
      },
     
      back = {
        text = 'Back',
        pos = vec2d.from(pages.home.buttons.back.pos),
        dim = vec2d.from(layout.button)
      },
      save = {
        text = 'Save',
        pos = vec2d.from(pages.home.buttons.save.pos),
        dim = vec2d.from(layout.button)
      },
      restore = {
        text = 'Restore',
        state = false, -- disabled
        pos = vec2d.from(pages.home.buttons.restore.pos),
        dim = vec2d.from(layout.button)
      },

      today = {
        text = 'Today',
        pos = vec2d.from(pages.home.buttons.today.pos),
        dim = vec2d.from(layout.button)
      },

      skipdays = {
        text = '',
        pos = vec2d.from(pages.home.buttons.skipdays.pos),
        dim = vec2d.from(layout.constraint_button)
      },
      
    },
    lists = {
      pending = list_reminder:create{
        pos = pages.home.lists.pending.pos,
        dim = layout.list,
        margin = layout.list_margin,
        item_dim = layout.list_item,
        text_margin = layout.list_text_margin,
        on_tick = function(self)
          self.internal_list = lume.filter(
            data.todays_reminders,
            function(item) return item.state == reminder.states.pending end
          )
        
          table.sort(self.internal_list, function(a, b)
            return data.remainder_times[a.id] < data.remainder_times[b.id]
          end)
        end,
        update_wrapped = function(self)
          for i, item in ipairs(self.internal_list) do
            local s = string.format(
              '%s: %s', 
              data.remainder_times[item.id] and 
              u.diff_string(data.remainder_times[item.id]) or
              '',
              item.message
            )
            local _, w = font:getWrap(s, self.item_dim.x - 2 * self.text_margin)
            self.wrapped[i] = w[1]
          end
        end
      },
      upcoming = list_reminder:create{
        pos = pages.home.lists.upcoming.pos,
        dim = layout.list,
        margin = layout.list_margin,
        item_dim = layout.list_item,
        text_margin = layout.list_text_margin,
        on_tick = function(self)
          self.internal_list = lume.filter(
            data.todays_reminders,
            function(item) return item.state == reminder.states.upcoming end
          )
        
          table.sort(self.internal_list, function(a, b)
            return data.remainder_times[a.id] < data.remainder_times[b.id]
          end)
        end,
        update_wrapped = function(self)
          for i, item in ipairs(self.internal_list) do
            local s = string.format(
              '%s: %s', 
              data.remainder_times[item.id] and 
              u.diff_string(data.remainder_times[item.id]) or
              '',
              item.message
            )
            local _, w = font:getWrap(s, self.item_dim.x - 2 * self.text_margin)
            self.wrapped[i] = w[1]
          end
        end
      },
      ongoing = list_reminder:create{
        pos = pages.home.lists.ongoing.pos,
        dim = layout.list,
        margin = layout.list_margin,
        item_dim = layout.list_item,
        text_margin = layout.list_text_margin,
        on_tick = function(self)
          self.internal_list = lume.filter(
            data.reminders,
            function(item) return item.state == reminder.states.ongoing end
          )
        end
      },
      completed = list_reminder:create{
        pos = pages.home.lists.completed.pos,
        dim = layout.list,
        margin = layout.list_margin,
        item_dim = layout.list_item,
        text_margin = layout.list_text_margin,
        opacity = 0.75,
        on_tick = function(self)
          self.internal_list = lume.filter(
            data.reminders,
            function(item) return item.state == reminder.states.completed end
          )
        end
      },
      all = list_reminder:create{
        pos = pages.home.lists.all.pos,
        dim = layout.list_all,
        margin = layout.list_margin,
        item_dim = layout.list_item_all,
        text_margin = layout.list_text_margin,
        on_tick = function(self)
          self.internal_list = {}
          local i = 1
          for k, r in pairs(data.reminders) do
            self.internal_list[i] = r
            i = i + 1
          end
        
          table.sort(self.internal_list, function (a, b)
            return a.message < b.message
          end)
        end,
        update_wrapped = function(self)
          for i, item in ipairs(self.internal_list) do
            local _, w = font:getWrap(
              string.format('%3d. %s', i, item.message),
              self.item_dim.x - 2 * self.text_margin
            )
            self.wrapped[i] = w[1]
          end
        end
      }
    },
    constraints = {
      date = {
        lists = {
          days = list_toggle:create{
            pos = pages.home.constraints.date.lists.days.pos,
            reference = lume.range(31),
            dim = layout.constraint_list
          },
          months = list_toggle:create{
            pos = pages.home.constraints.date.lists.months.pos,
            reference = lume.range(12),
            translator = months,
            dim = layout.constraint_list
          },
          years = list_toggle:create{
            pos = pages.home.constraints.date.lists.years.pos,
            reference = lume.range(200),
            translator = years_translator,
            dim = layout.constraint_list
          },
          weekdays = list_toggle:create{
            pos = pages.home.constraints.date.lists.weekdays.pos,
            reference = lume.range(0, 6),
            translator = weekdays,
            dim = layout.constraint_list
          },
          skipdays = list_toggle_2:create{
            pos = pages.home.constraints.date.lists.skipdays.pos,
            dim = layout.constraint_list,
            reference = lume.range(31)
          }
        },
        texts = {
          days = 'Days',
          months = 'Months',
          years = 'Years',
          weekdays = 'Week Days',
          skipdays = 'Skip Days',
        },
        buttons = {
          days = {
            state = true,
            pos = vec2d.from(pages.home.constraints.date.buttons.days.pos),
            dim = vec2d.from(layout.constraint_button)
          },
          months = {
            state = true,
            pos = vec2d.from(pages.home.constraints.date.buttons.months.pos),
            dim = vec2d.from(layout.constraint_button)
          },
          years = {
            state = true,
            pos = vec2d.from(pages.home.constraints.date.buttons.years.pos),
            dim = vec2d.from(layout.constraint_button)
          },
          weekdays = {
            state = true,
            pos = vec2d.from(pages.home.constraints.date.buttons.weekdays.pos),
            dim = vec2d.from(layout.constraint_button)
          }
        },
        o_lists = {
          days = list:create{
            pos = pages.home.constraints.date.o_lists.days.pos,
            dim = layout.constraint_o_list,
            items = data.edit.constraints.date.lists.days
          },
          months = list:create{
            translator = months,
            pos = pages.home.constraints.date.o_lists.months.pos,
            dim = layout.constraint_o_list,
            items = data.edit.constraints.date.lists.months
          },
          years = list:create{
            translator = years_translator,
            pos = pages.home.constraints.date.o_lists.years.pos,
            dim = layout.constraint_o_list,
            items = data.edit.constraints.date.lists.years
          },
          weekdays = list:create{
            translator = weekdays,
            pos = pages.home.constraints.date.o_lists.weekdays.pos,
            dim = layout.constraint_o_list,
            items = data.edit.constraints.date.lists.weekdays
          },
          skipdays = list_2:create{
            pos = pages.home.constraints.date.o_lists.skipdays.pos,
            dim = layout.constraint_o_list,
            items = data.edit.constraints.date.lists.skipdays
          },
        },
        skip_ref = date_setter:create{
          pos = pages.home.constraints.date.skip_ref.pos,
          data = data.edit.constraints.date.addendum.skip_ref
        }
      }
    },
    texts = {
      pending = {
        text = 'Pending',
        bg = true,
        pos = vec2d.from(pages.home.texts.pending.pos),
        dim = vec2d.from(layout.text)
      },
      ongoing = {
        text = 'Ongoing',
        bg = true,
        pos = vec2d.from(pages.home.texts.ongoing.pos),
        dim = vec2d.from(layout.text)
      },
      upcoming = {
        text = 'Upcoming',
        bg = true,
        pos = vec2d.from(pages.home.texts.upcoming.pos),
        dim = vec2d.from(layout.text)
      },
      completed = {
        text = 'Completed',
        bg = true,
        pos = vec2d.from(pages.home.texts.completed.pos),
        dim = vec2d.from(layout.text)
      },
      all = {
        text = 'All',
        bg = true,
        pos = vec2d.from(pages.home.texts.all.pos),
        dim = vec2d.from(layout.text_all)
      },
      summary = {
        text = 'Summary',
        pos = vec2d.from(pages.home.texts.summary.pos),
        dim = vec2d{
          x = layout.window.x - 2 * layout.border,
          y = layout.text.y
        }
      },
      constraints = {
        text = 'Constraints',
        pos = vec2d.from(pages.home.texts.constraints.pos),
        dim = vec2d{
          x = layout.window.x - 2 * layout.border,
          y = layout.text.y
        }
      },

      feedback = {
        text = '<>',
        pos = vec2d.from(pages.home.texts.feedback.pos),
        dim = vec2d{
          x = 2 * layout.button.x + layout.border,
          y = layout.button.y
        }
      }
    },
    lines = {
      summary_title_line = {
        pages.home.lines.summary_title_line[1],
        pages.home.lines.summary_title_line[2],
        pages.home.lines.summary_title_line[3],
        pages.home.lines.summary_title_line[4],
      }
    },
    summary = {
      pos = vec2d.from(pages.home.summary.pos),
      dim = vec2d{
        x = layout.window.x - 2 * layout.border,
        y = layout.window.y - 2 * layout.border
      }
    },
    typer = typer:create{
      pos = pages.home.typer.pos,
      dim = {
        x = layout.window.x - 4 * layout.border,
        y = 10 * font:getHeight()
      },
      data = data.edit
    },
    time_setter = time_setter:create{
      pos = pages.home.time_setter.pos,
      data = data.edit.time
    },
    summary_pane = summary_pane:create{
      pos = pages.summary.hide.summary_pane.pos,
      dim = layout.summary_pane,
      margin = layout.border
    },
    progress_bar = progress_bar:create{
      pos = pages.home.progress_bar.pos,
      dim = layout.progress_bar,
    },
    clock = clock:create{
      pos = pages.home.clock.pos,
      dim = pages.home.clock.dim
    }
  }
end

function love.draw()

  love.graphics.setColor(1, 1, 1)
  local summary = program.summary
  love.graphics.rectangle(
    'fill',
    summary.pos.x, summary.pos.y,
    summary.dim.x, summary.dim.y,
    3
  )

  love.graphics.setColor(1, 1, 1)
  program.summary_pane:draw()

  program.typer:draw(current_page == pages.edit[1])

  for _, button in pairs(program.buttons) do
    local c = button.state == false and 0.7 or 1
    love.graphics.setColor(c, c, c)
    love.graphics.rectangle(
      'fill',
      button.pos.x, button.pos.y,
      button.dim.x, button.dim.y,
      3
    )

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle(
      'line',
      button.pos.x, button.pos.y,
      button.dim.x, button.dim.y,
      3
    )

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      button.text,
      button.pos.x,
      button.pos.y + (button.dim.y - font:getHeight()) / 2,
      button.dim.x,
      'center'
    )
  end

  program.progress_bar:draw()

  for _, instance in pairs(program.lists) do
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle(
      'fill',
      instance.pos.x, instance.pos.y,
      instance.dim.x, instance.dim.y,
      3
    )
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle(
      'line',
      instance.pos.x, instance.pos.y,
      instance.dim.x, instance.dim.y,
      3
    )

    instance:draw(true)
  end

  for k, instance in pairs(program.constraints.date.lists) do

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      program.constraints.date.texts[k],
      instance.pos.x, instance.pos.y - (layout.border + font:getHeight()),
      instance.dim.x,
      'center'
    )

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle(
      'line',
      instance.pos.x,
      instance.pos.y,
      instance.dim.x,
      instance.dim.y
    )
    
    love.graphics.setColor(1, 1, 1)
    instance:draw()
  end

  for k, button in pairs(program.constraints.date.buttons) do

    local c = button.state and 1 or 0.85
    love.graphics.setColor(c, c, c)
    love.graphics.rectangle(
      'fill',
      button.pos.x, button.pos.y,
      button.dim.x,
      button.dim.y,
      3
    )

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle(
      'line',
      button.pos.x, button.pos.y,
      button.dim.x,
      button.dim.y,
      3
    )

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      string.format('P: %s', button.state),
      button.pos.x,
      button.pos.y + (button.dim.y - font:getHeight()) / 2,
      button.dim.x,
      'center'
    )
  end

  for k, instance in pairs(program.constraints.date.o_lists) do
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle(
      'line',
      instance.pos.x,
      instance.pos.y,
      instance.dim.x,
      instance.dim.y
    )
    
    if not next(instance.items) then
      love.graphics.setColor(u.t_c(theme.font_color))
      love.graphics.printf(
        'No constraints.',
        instance.pos.x + instance.margin,
        instance.pos.y + instance.margin,
        instance.dim.x - 2 * instance.margin,
        'center'
      )
    end

    love.graphics.setColor(1, 1, 1)
    if k ~= 'skipdays' then
      instance:draw(program.constraints.date.buttons[k].state)
    else
      instance:draw(true)
    end
  end

  love.graphics.setColor(0, 0, 0, 0.4)
  for _, line in pairs(program.lines) do
    love.graphics.line(line)
  end

  love.graphics.setColor(1, 1, 1)
  for _, text in pairs(program.texts) do

    love.graphics.setColor(1, 1, 1, text.bg and 1 or 0)
    love.graphics.rectangle(
      'fill',
      text.pos.x,
      text.pos.y,
      text.dim.x,
      text.dim.y,
      3
    )

    love.graphics.setColor(0, 0, 0, text.bg and 1 or 0)
    love.graphics.rectangle(
      'line',
      text.pos.x,
      text.pos.y,
      text.dim.x,
      text.dim.y,
      3
    )

    love.graphics.setColor(u.t_c(theme.font_color))
    love.graphics.printf(
      text.text,
      text.pos.x,
      text.pos.y + (text.dim.y - font:getHeight()) / 2,
      text.dim.x,
      'center'
    )
  end

  love.graphics.setColor(1, 1, 1)
  program.time_setter:draw(current_page == pages.edit[2])

  program.constraints.date.skip_ref:draw(current_page == pages.edit[3])

  program.clock:draw()
end

function love.update(dt)
  local curr = os.time()
  if data.now ~= curr then
    data.now = curr
    -- do stuff
    update_todays_reminders()
    
    program.progress_bar:on_tick(data.completion_rate)
    program.clock:on_tick(data.now)
    
    for _, l in pairs(program.lists) do
      l:on_tick()
    end

    program.texts.all.text = string.format('All (%d)', #program.lists.all.internal_list)
  end

  anim:update(dt)
  timer:update(dt)
end

function love.keypressed(key)
  if key == 'escape' then
    go_back()
  end

  if key == 'z' and love.keyboard.isDown('lctrl') then
    undo_purge()
  end

  if current_page == pages.edit[1] then
    program.typer:keypressed(key)
    if key == 'tab' then
      transition_to(pages.edit[2])
    end
  elseif current_page == pages.edit[2] then
    if key == 'tab' and love.keyboard.isDown('lctrl') then
      transition_to(pages.edit[3])
    else
      program.time_setter:keypressed(key)
    end
  elseif current_page == pages.edit[3] then
    if key == 'tab' and love.keyboard.isDown('lctrl') then
      create_reminder()
      transition_to(pages.home)
    end

    if u.collides(cursor, program.buttons.skipdays) then
      program.constraints.date.skip_ref:keypressed(key)
    end
  end
end

function love.textinput(t)
  if current_page == pages.edit[1] then
    program.typer:textinput(t)
  end
end

function love.mousemoved(x, y)
  cursor:update{x = x, y = y}
end

function love.mousereleased(x, y, button)
  cursor:update{x = x, y = y}

  -- buttons
  if u.collides(cursor, program.buttons.back) then
    go_back()
    return
  end

  if current_page == pages.home then
    if u.collides(cursor, program.buttons.add) then
      if data.last_clicked_list then
        data.last_clicked_list.active = nil
        data.selected_reminder = nil
      end
      transition_to(pages.edit[1])
      view_summary()
      return
    elseif u.collides(cursor, program.buttons.restore) and
    program.buttons.restore.state == true then
      undo_purge()
    elseif u.collides(cursor, program.buttons.all) then
      if data.last_clicked_list then
        data.last_clicked_list.active = nil
        data.selected_reminder = nil
      end
      
      transition_to(pages.all)
      view_summary()
      return
    end

    local persist_summary = false
    if data.selected_reminder then
      if u.collides(cursor, program.buttons.doing) then
        on_doing()
        persist_summary = true
      elseif u.collides(cursor, program.buttons.reset) then
        persist_summary = true
        on_reset()
      elseif u.collides(cursor, program.buttons.finish) then
        on_finish()
        persist_summary = true
      elseif u.collides(cursor, program.buttons.archive) then
        on_archive()
      elseif u.collides(cursor, program.buttons.delete) then
        on_delete()
      elseif u.collides(cursor, program.buttons.edit) then
        fill_edit_fields()

        -- do on add things
        if data.last_clicked_list then
          data.last_clicked_list.active = nil
          data.selected_reminder = nil
        end
        transition_to(pages.edit[1])
        view_summary()
      end
    end

    local l_active = nil
    for _, l in pairs(program.lists) do
      if u.collides(cursor, l) then
        local k, r = l:clicked_on(x, y)
        data.last_clicked_list = l
        data.selected_reminder_key = k
        l_active = l
        view_summary(r)
      else
        l.active = nil
      end
    end
    if l_active == nil and not persist_summary then
      view_summary()
    end
    if persist_summary then
      if data.selected_reminder.state == reminder.states.ongoing then
        program.lists.ongoing.active = data.selected_reminder_key
      elseif data.selected_reminder.state == reminder.states.upcoming then
        program.lists.upcoming.active = data.selected_reminder_key
      elseif data.selected_reminder.state == reminder.states.completed then
        program.lists.completed.active = data.selected_reminder_key
      end
      view_summary(data.selected_reminder)
    end

  elseif current_page == pages.edit[1] or current_page == pages.edit[2] then
    if u.collides(cursor, program.buttons.next) then
      transition_to(next_page())
    end
  elseif current_page == pages.edit[3] then
    -- normal buttons
    if u.collides(cursor, program.buttons.done) then
      create_reminder()
      transition_to(pages.home)
    elseif u.collides(cursor, program.buttons.today) then
      local today = os.date('*t', data.today)
      set_fields{
        days = {[today.day] = true},
        months = {[today.month] = true},
        years = {[today.year] = true}
      }
    end

    -- constraints
    for k, instance in pairs(program.constraints.date.lists) do
      if u.collides(cursor, instance) then
        local i, v, s = instance:clicked_on(x, y, button)
        if i then
          if k == 'years' then
            program.constraints.date.o_lists[k].items[v] = toggle_translate[s]
          elseif k ~= 'skipdays' then
            program.constraints.date.o_lists[k].items[i] = toggle_translate[s]
          else
            program.constraints.date.o_lists[k].items[i] = skip_translate[s]
          end
        end
      end
    end
    for k, b in pairs(program.constraints.date.buttons) do
      if u.collides(cursor, b) then
        -- change polarity
        b.state = not b.state
      end
    end
  elseif current_page == pages.all then

    -- summary stuff
    if data.selected_reminder then
      if u.collides(cursor, program.buttons.archive) then
        on_archive()
      elseif u.collides(cursor, program.buttons.delete) then
        on_delete()
      elseif u.collides(cursor, program.buttons.doing) then
        on_doing()
      elseif u.collides(cursor, program.buttons.finish) then
        on_finish()
      elseif u.collides(cursor, program.buttons.edit) then
        -- do edit things
        fill_edit_fields()

        -- do on add things
        if data.last_clicked_list then
          data.last_clicked_list.active = nil
          data.selected_reminder = nil
        end
        transition_to(pages.edit[1])
        view_summary_all()
      end
    end

    local l = program.lists.all
    if u.collides(cursor, l) then
      local k, r = l:clicked_on(x, y)
      data.last_clicked_list = l
      data.selected_reminder_key = k
      view_summary_all(r)
    else
      l.active = nil
      view_summary_all()
    end

    -- save stuff
    if u.collides(cursor, program.buttons.save) then
      light_save_ops()
      view_feedback('Saved!')

      sounds.pling_save:stop()
      sounds.pling_save:play()
    elseif u.collides(cursor, program.buttons.restore) and
    program.buttons.restore.state == true then
      undo_purge()
    end
  end
end

function love.wheelmoved(x, y)
  if current_page == pages.home then
    for k, instance in pairs(program.lists) do
      if k ~= 'all' then
        if u.collides(cursor, instance) then
          instance:scroll(y)
        end
      end
    end
  elseif current_page == pages.all then
    if u.collides(cursor, program.lists.all) then
      program.lists.all:scroll(y)
    end
  elseif current_page == pages.edit[2] then
    program.time_setter:wheelmoved(x, y)
  elseif current_page == pages.edit[3] then
    for _, instance in pairs(program.constraints.date.lists) do
      if u.collides(cursor, instance) then
        instance:scroll(y)
      end
    end
  
    for _, instance in pairs(program.constraints.date.o_lists) do
      if u.collides(cursor, instance) then
        instance:scroll(y)
      end
    end

    if u.collides(cursor, program.buttons.skipdays) then
      program.constraints.date.skip_ref:wheelmoved(x, y)
    end
  end
end

------------------------------------------------------