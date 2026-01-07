---@class iedit.session
---@field restriction Range2
---@field extmarks integer[]
---@field restriction_first_extmark integer
---@field restriction_last_extmark integer
---@field text string[]
---@field au_id number

local ns=vim.api.nvim_create_namespace('iedit')

---@param text string[]
---@return Range4[]
local function find_all(buf, text)
  local ranges={}

  local row=1
  local col=1
  local lines=vim.api.nvim_buf_get_lines(buf,0,-1,true)
  local erow=#lines

  while (row+#text-1)<=erow do
    ---@type integer
    local rcol

    for trow,tline in ipairs(text) do
      local pat=vim.pesc(tline)
      if trow~=1 then pat='^'..pat end
      if trow~=#text then pat=pat..'$' end
      local fcol,len=assert(lines[row+trow-1]):find(pat,trow==1 and col or 1) --[[@as integer]]
      if not fcol or len==0 then
        col=1
        row=row+1
        goto continue
      elseif trow==1 then
        rcol=fcol
      end
    end

    local rrow=row
    row=row+#text-1
    col=#text==1 and rcol+#text[1] or #text[#text]+1
    table.insert(ranges,{rrow-1,rcol-1,row-1,col-1})
    ::continue::
  end

  return ranges
end

---@class iedit.config
---@field highlight string
---@field end_right_gravity boolean
---@field right_gravity boolean
local def_conf={
  highlight = 'IncSearch',
  end_right_gravity = true,
  right_gravity = false,
}

---@type iedit.config
local config = def_conf

---@alias iedit.user_config Partial<iedit.config>

local function stop(buf)
  vim.api.nvim_buf_clear_namespace(buf or 0, ns, 0, -1)

  if vim.b.iedit_session then
    vim.api.nvim_del_autocmd(vim.b[buf or 0].iedit_session.au_id)
  end

  vim.b.iedit_session=nil
end

---@return Range4
local function mark_id_to_range(buf,mark_id)
    local mark=vim.api.nvim_buf_get_extmark_by_id(buf,ns,mark_id,{details=true})
    return {mark[1],mark[2],assert(assert(mark[3]).end_row),assert(assert(mark[3]).end_col)}
end

local function range_contains_pos(range,pos)
  return (range[1]<pos[1] or (range[1]==pos[1] and range[2]<=pos[2]))
    and (range[3]>pos[1] or (range[3]==pos[1] and range[4]>pos[2]))
end

---@param buf integer
---@param extmarks integer[]
---@param range Range4
local function insert_in_sorted_and_uniq(buf,extmarks, range)
  local lo=1
  local hi=#extmarks+1
  while lo<hi do
    local mid=math.floor((lo+hi)/2)
    local mrange=mark_id_to_range(buf,extmarks[mid])
    if (mrange[3]<range[1]) or (mrange[3]==range[1] and mrange[4]<=range[2]) then
      lo=mid+1
    else
      hi=mid
    end
  end

  if extmarks[lo] then
    local mrange=mark_id_to_range(buf,extmarks[lo])
    if (mrange[1]<range[3] or (mrange[1]==range[3] and mrange[2]<range[4])) then
      return
    end
  end

  table.insert(extmarks,lo,vim.api.nvim_buf_set_extmark(buf,ns,range[1],range[2],{
    end_line=range[3],
    end_col=range[4],
    hl_group=config.highlight,
    end_right_gravity=config.end_right_gravity,
    right_gravity=config.right_gravity,
  }))
end

---@param ranges Range4[]
---@param restriction Range2?
local function start(ranges,restriction)
  stop()

  if restriction then
    while ranges[1] and ranges[1][1]<(restriction[1]-1) do
      table.remove(ranges,1)
    end

    while ranges[#ranges] and ranges[#ranges][3]>(restriction[2]-1) do
      table.remove(ranges)
    end
  end

  if not ranges[1] then
    return
  end

  local match_text=vim.api.nvim_buf_get_text(0,ranges[1][1],ranges[1][2],ranges[1][3],ranges[1][4],{})
  local old_text=table.concat(match_text,'\n')

  local extmarks={}

  for _,range in ipairs(ranges) do
    table.insert(extmarks,vim.api.nvim_buf_set_extmark(0,ns,range[1],range[2],{
      end_line=range[3],
      end_col=range[4],
      hl_group=config.highlight,
      end_right_gravity=config.end_right_gravity,
      right_gravity=config.right_gravity,
    }))
  end

  local restriction_offset
  if restriction then
    local start_row=mark_id_to_range(0,extmarks[1])[1]
    local end_row=mark_id_to_range(0,extmarks[#extmarks])[3]
    restriction_offset={(restriction[1]-1)-start_row,(restriction[2]-1)-end_row}
  else
    restriction_offset={0,0}
  end

  local au_id=vim.api.nvim_create_autocmd({'TextChanged','TextChangedI','TextChangedP'},{
    group=vim.api.nvim_create_augroup('Iedit',{clear=false}),
    buffer=0,
    callback=function (ev)
      ---@type iedit.session
      local session=vim.b[ev.buf].iedit_session
      if not session then
        stop(ev.buf)
        return true
      end

      local new_text

      for _,mark_id in ipairs(session.extmarks) do
        local range=mark_id_to_range(ev.buf,mark_id)

        local text=vim.api.nvim_buf_get_text(ev.buf,range[1],range[2],range[3],range[4],{})

        if table.concat(text,'\n')~=old_text then
          new_text=text
          break
        end
      end

      if not new_text then
        return
      end

      old_text=table.concat(new_text,'\n')

      if vim.fn.undotree(ev.buf).seq_cur~=vim.fn.undotree(ev.buf).seq_last then
        return
      end

      vim.cmd.undojoin()

      for _,mark_id in pairs(session.extmarks) do
        local range=mark_id_to_range(ev.buf,mark_id)
        vim.api.nvim_buf_set_extmark(ev.buf,ns,range[1],range[2],{
          end_line=range[3],
          end_col=range[4],
          end_right_gravity=false,
          right_gravity=true,
          id=mark_id,
        })
      end
      for _,mark_id in pairs(session.extmarks) do
        local range=mark_id_to_range(ev.buf,mark_id)
        vim.api.nvim_buf_set_text(ev.buf,range[1],range[2],range[3],range[4],new_text)
        vim.api.nvim_buf_set_extmark(ev.buf,ns,range[1],range[2],{
          end_line=range[1]+#new_text-1,
          end_col=(#new_text==1 and range[2] or 0)+#new_text[#new_text],
          end_right_gravity=false,
          right_gravity=true,
          id=mark_id,
        })
      end
      for _,mark_id in pairs(session.extmarks) do
        local range=mark_id_to_range(ev.buf,mark_id)
        vim.api.nvim_buf_set_extmark(ev.buf,ns,range[1],range[2],{
          end_line=range[3],
          end_col=range[4],
          hl_group = config.highlight,
          end_right_gravity=config.end_right_gravity,
          right_gravity=config.right_gravity,
          id=mark_id,
        })
      end
    end,
  })

  ---@type iedit.session
  local session={
    extmarks=extmarks,
    restriction=restriction_offset,
    au_id=au_id,
    text=match_text,
    restriction_first_extmark=extmarks[1],
    restriction_last_extmark=extmarks[#extmarks],
  }

  vim.b.iedit_session=session
end

---@param session iedit.session
local function get_restriction_start(session,buf)
  return mark_id_to_range(buf,session.restriction_first_extmark)[1]+1+session.restriction[1]
end

---@param session iedit.session
local function get_restriction_end(session,buf)
  return mark_id_to_range(buf,session.restriction_last_extmark)[3]+1+session.restriction[2]
end

local M={}

---@param conf iedit.user_config?
function M.setup(conf)
  if conf then
    config=vim.tbl_deep_extend('force',def_conf,conf --[[@as iedit.config]])
  end
end

function M.restrict_current_line()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local row=vim.fn.line'.'
  start(find_all(0, session.text),{row,row})
end
function M.restrict_visual()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local start_row=vim.fn.line'.'
  local end_row=vim.fn.line'.'

  if start_row>end_row then
    start_row,end_row=end_row,start_row
  end

  start(find_all(0, session.text),{start_row,end_row})
end
---@param start_row integer?
---@param end_row integer?
---@param is_offset boolean?
function M.restrict_range(start_row, end_row, is_offset)
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  if is_offset then
    start_row=get_restriction_start(session,0)+(start_row or 0)
    end_row=get_restriction_end(session,0)+(end_row or 0)
  else
    start_row=start_row or get_restriction_start(session,0)
    end_row=end_row or get_restriction_end(session,0)
  end

  start(find_all(0, session.text),{start_row,end_row})
end
function M.expand_up()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local start_row=get_restriction_start(session,0)-1
  local end_row=get_restriction_end(session,0)

  start(find_all(0, session.text),{start_row,end_row})
end
function M.expand_down()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local start_row=get_restriction_start(session,0)
  local end_row=get_restriction_end(session,0)+1

  start(find_all(0, session.text),{start_row,end_row})
end
function M.unexpand_up()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local start_row=get_restriction_start(session,0)+1
  local end_row=get_restriction_end(session,0)

  start(find_all(0, session.text),{start_row,end_row})
end
function M.unexpand_down()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local start_row=get_restriction_start(session,0)
  local end_row=get_restriction_end(session,0)-1

  start(find_all(0, session.text),{start_row,end_row})
end
function M.expand_next_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local ranges=find_all(0, session.text)
  local range=mark_id_to_range(0,session.extmarks[#session.extmarks])
  for _,mrange in ipairs(ranges) do
    if mrange[1]>range[3] or (mrange[1]==range[3] and mrange[2]>=range[4]) then
      start(find_all(0, session.text),{get_restriction_start(session,0),mrange[3]+1})
      return
    end
  end
end
function M.expand_prev_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local ranges=find_all(0, session.text)
  local range=mark_id_to_range(0,session.extmarks[1])
  local idx=#ranges
  while ranges[idx] do
    local mrange=ranges[idx]
    idx=idx-1
    if mrange[3]<range[1] or (mrange[3]==range[1] and mrange[4]<=range[2]) then
      start(find_all(0, session.text),{mrange[1]+1,get_restriction_end(session,0)})
      return
    end
  end
end
function M.unexpand_next_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local mark_id=session.extmarks[#session.extmarks-1]
  if not mark_id then
    stop()
  end

  start(find_all(0, session.text),{get_restriction_start(session,0),mark_id_to_range(0,mark_id)[3]+1})
end
function M.unexpand_prev_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local mark_id=session.extmarks[2]
  if not mark_id then
    stop()
  end

  start(find_all(0, session.text),{mark_id_to_range(0,mark_id)[1]+1,get_restriction_end(session,0)})
end
function M.toggle_current_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local row=vim.fn.line'.'-1
  local col=vim.fn.col'.'-1

  for k,mark_id in ipairs(session.extmarks) do
    local mrange=mark_id_to_range(0,mark_id)
    if range_contains_pos(mrange,{row,col}) then
      table.remove(session.extmarks,k)
      if session.restriction_first_extmark==mark_id then
        session.restriction_first_extmark=vim.api.nvim_buf_set_extmark(0,ns,mrange[1],mrange[2],{
          end_right_gravity=config.end_right_gravity,
          right_gravity=config.right_gravity,
          end_row=mrange[3],
          end_col=mrange[4],
        })
      end
      if session.restriction_last_extmark==mark_id then
        session.restriction_last_extmark=vim.api.nvim_buf_set_extmark(0,ns,mrange[1],mrange[2],{
          end_right_gravity=config.end_right_gravity,
          right_gravity=config.right_gravity,
          end_row=mrange[3],
          end_col=mrange[4],
        })
      end
      vim.api.nvim_buf_del_extmark(0,ns,mark_id)
      vim.b.iedit_session=session
      return
    end
  end

  for _,range in ipairs(find_all(0,session.text)) do
    if range[1]>row or (range[1]==row and range[2]>col) then
      break
    elseif range_contains_pos(range,{row,col}) then
      insert_in_sorted_and_uniq(0,session.extmarks,range)
      vim.b.iedit_session=session
      return
    end
  end
end

---@param match string[]?
function M.toggle(match)
  if vim.b.iedit_session then
    stop()
    return
  end

  if not match then
    if vim.fn.mode()=='n' then
      match={vim.fn.expand('<cword>')}
      if not match[1] then
        vim.notify('No word under (or after) cursor',vim.log.levels.WARN)
        return
      end
      --TODO: match word (e.g. \<\w+\>), just make it a toggle_word_delim
    elseif vim.fn.mode()=='v' or vim.fn.mode()=='V' then
      match=vim.fn.getregion(vim.fn.getpos('v'),vim.fn.getpos('.'),{type=vim.fn.mode()})
    else
      vim.notify(('mode `%s` not supported'):format(vim.fn.mode()),vim.log.levels.WARN)
      return
    end
  else
    assert(type(match)=='table', '{match} should be a list of string')
  end

  local ranges=find_all(0, match)

  if vim.tbl_isempty(ranges) then
    vim.notify(('no {mach} found'))
    return
  end

  start(ranges)
end

function M.goto_next_occurrence(wrap)
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local row=vim.fn.line'.'-1
  local col=vim.fn.col'.'-1

  for _,mark_id in ipairs(session.extmarks) do
    local range=mark_id_to_range(0,mark_id)
    if range[1]>row or (range[1]==row and range[2]>col) then
      vim.api.nvim_win_set_cursor(0,{range[1]+1,range[2]})
      return
    end
  end

  if wrap then
    M.goto_first_occurrence()
  end
end
function M.goto_last_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local range=mark_id_to_range(0,session.extmarks[#session.extmarks])
  vim.api.nvim_win_set_cursor(0,{range[1]+1,range[2]})
end
function M.goto_prev_occurrence(wrap)
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local row=vim.fn.line'.'-1
  local col=vim.fn.col'.'-1

  local idx=#session.extmarks
  while session.extmarks[idx] do
    local range=mark_id_to_range(0,session.extmarks[idx])
    idx=idx-1
    if range[1]<row or (range[1]==row and range[2]<col) then
      vim.api.nvim_win_set_cursor(0,{range[1]+1,range[2]})
      return
    end
  end

  if wrap then
    M.goto_last_occurrence()
  end
end
function M.goto_first_occurrence()
  ---@type iedit.session
  local session=vim.b[0].iedit_session
  if not session then
    return
  end

  local range=mark_id_to_range(0,session.extmarks[1])
  vim.api.nvim_win_set_cursor(0,{range[1]+1,range[2]})
end

return M
