local M={}
M.ns=vim.api.nvim_create_namespace'iedit_selector'
function M.find_next(buf,pos,text)
    if #text==1 then
        for row,line in ipairs(vim.api.nvim_buf_get_lines(buf,pos[1],-1,true)) do
            local start_col,end_col
            if row==1 then
                start_col,end_col=vim.fn.getline(pos[1]+1):find(text[1],pos[2]+1,true)
            else
                start_col,end_col=line:find(text[1],1,true)
            end
            if start_col then
                return {row+pos[1]-1,start_col-1,row+pos[1]-1,end_col}
            end
        end
        return
    end

    local lines=vim.api.nvim_buf_get_lines(buf,pos[1],-1,true)
    for row,_ in ipairs(lines) do
        local flag=true

        for trow,tline in ipairs(text) do
            tline=vim.pesc(tline)
            if trow~=1 then tline='^'..tline end
            if trow~=#text then tline=tline..'$' end
            if not lines[row+trow-1] or not lines[row+trow-1]:find(tline,row==1 and pos[1] or 1) then
                flag=false
                break
            end
        end

        if flag then
            return {row+pos[1]-1,#lines[row]-#text[1],row+pos[1],#text[#text]}
        end
    end
end
function M.find_all_ocurances(buf,text,curpos)
    local row,col=unpack(curpos)
    local pos={0,0}
    local ranges={}
    local idx
    while true do
        local range=M.find_next(buf,pos,text)
        if range==nil then break end
        if not idx and (range[3]>row or (range[3]==row and range[4]>col)) then
            idx=#ranges+1
        end
        table.insert(ranges,range)
        pos={range[3],range[4]}
    end
    return ranges,idx or 1
end
function M.start_loop(ranges,idx,config)
    assert(idx>0 and idx<=#ranges)
    local selected=setmetatable({},{})
    local function get(id)
        return selected[id] and true or false
    end
    local function del(id)
        if not get(id) then return end
        vim.api.nvim_buf_del_extmark(0,M.ns,getmetatable(selected)[id])
        selected[id]=nil
    end
    local function set(id)
        if get(id) then return end
        local range=ranges[id]
        selected[id]=range
        getmetatable(selected)[id]=vim.api.nvim_buf_set_extmark(0,M.ns,range[1],range[2],{
            hl_group=config.highlight.selected,
            end_line=range[3],
            end_col=range[4],
            strict=false,
        })
    end
    local function clean()
        vim.api.nvim_buf_clear_namespace(0,M.ns,0,-1)
    end
    local current_virt_id
    local current_hl_id
    while true do
        idx=(idx-1)%(#ranges)+1
        if current_virt_id then
            vim.api.nvim_buf_del_extmark(0,M.ns,current_virt_id)
            current_virt_id=nil
        end
        if current_hl_id then
            vim.api.nvim_buf_del_extmark(0,M.ns,current_hl_id)
            current_hl_id=nil
        end
        if get(idx) then
            current_virt_id=vim.api.nvim_buf_set_extmark(0,M.ns,ranges[idx][1],ranges[idx][2],{
                virt_text={{'iedit: Has selected underneath',config.highlight.selected}},
            })
        end
        current_hl_id=vim.api.nvim_buf_set_extmark(0,M.ns,ranges[idx][1],ranges[idx][2],{
            hl_group=config.highlight.current,
            end_line=ranges[idx][3],
            end_col=ranges[idx][4],
            strict=false,
        })
        local help={}
        for key,actions in vim.spairs(config.map) do
            table.insert(help,key..' -> '..table.concat(actions,'&'))
        end
        print(table.concat(help,'  '):sub(1,vim.v.echospace))
        local save_cursor=vim.api.nvim_win_get_cursor(0)
        vim.api.nvim_win_set_cursor(0,{ranges[idx][1]+1,0})
        vim.cmd.norm{'zz',bang=true}
        vim.cmd.redraw{bang=true}
        vim.api.nvim_win_set_cursor(0,save_cursor)
        local s,charstr=pcall(vim.fn.getcharstr)
        if not s then
            clean()
            error(charstr)
        end
        local key=vim.fn.keytrans(charstr)
        for _,action in ipairs(config.map[key] or {}) do
            if action=='done' then
                clean() return vim.tbl_values(selected)
            elseif action=='select' then
                set(idx)
            elseif action=='unselect' then
                del(idx)
            elseif action=='toggle' then
                if get(idx) then del(idx) else set(idx) end
            elseif action=='next' then
                idx=idx+1
            elseif action=='prev' then
                idx=idx-1
            elseif action=='all' then
                clean() return ranges
            end
        end
    end
end
function M.start(range,config)
    local row,col=unpack(vim.api.nvim_win_get_cursor(0))
    local text=vim.api.nvim_buf_get_text(0,range[1],range[2],range[3],range[4],{})
    if #text==1 and text[1]=='' then
        vim.notify('No text selected',vim.log.levels.WARN)
        return
    end
    local ranges,idx=M.find_all_ocurances(0,text,{row-1,col})
    return M.start_loop(ranges,idx,config)
end
return M
