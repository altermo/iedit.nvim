local M={}

M.default_config={
    select={
        map=setmetatable({
            q={'done'},
            ['<Esc>']={'select','done'},
            ['<CR>']={'toggle'},
            n={'toggle','next'},
            p={'toggle','prev'},
            N={'next'},
            P={'prev'},
            a={'all'},
            --u={'unselect'},
        },{__t=true--[[Don't merge subsequent tables]]}),
        highlight={
            current='CurSearch',
            selected='Search'
        }
    },
    highlight='IncSearch',
}

M.config=vim.deepcopy(M.default_config)

local function merge(origin,new)
    if type(origin)~='table' and type(new)~='table' then
        return vim.F.if_nil(new,origin)
    end
    if new==nil then return origin end
    if not origin or new.merge==false then
        return new
    end
    local keys=vim.defaulttable(function() return {} end)
    for k,v in pairs(origin) do
        keys[k][1]=v
    end
    for k,v in pairs(new) do
        keys[k][2]=v
    end
    local ret={}
    for k,v in pairs(keys) do
        if getmetatable(origin).__t then
            ret[k]=vim.F.if_nil(v[2],v[1])
        else
            ret[k]=merge(v[1],v[2])
        end
    end
    return ret
end

function M.setup(config)
    merge(M.default_config,config)
end

function M.select(_opts)
    _opts=_opts or {}
    M.stop()
    local range={}
    if vim.fn.mode()=='n' then
        local line=vim.fn.getline'.'
        local col=vim.fn.col'.'
        local row=vim.fn.line'.'-1
        local regex=vim.regex[[\k]]
        range={row,nil,row,nil}
        while not regex:match_str(line:sub(col,col)) do
            col=col+1
            if #line<col then
                vim.notify('No word under (or after) cursor',vim.log.levels.WARN)
                return
            end
        end
        while regex:match_str(line:sub(col+1,col+1)) do col=col+1 end
        range[4]=col
        while regex:match_str(line:sub(col,col)) do col=col-1 end
        range[2]=col
    elseif vim.fn.mode()=='v' or vim.fn.mode()=='V' then
        local pos1=vim.fn.getpos('v')
        local pos2=vim.fn.getpos('.')
        if pos1[2]>pos2[2] or (pos1[2]==pos2[2] and pos1[3]>pos2[3]) then
            pos1,pos2=pos2,pos1
        end
        range={pos1[2]-1,pos1[3]-1,pos2[2]-1,pos2[3]}
        vim.cmd.norm{'\x1b',bang=true}
    else
        error(('mode `%s` not supported'):format(vim.fn.mode()))
    end
    local ranges
    if _opts.all then
        local text=vim.api.nvim_buf_get_text(0,range[1],range[2],range[3],range[4],{})
        if #text==1 and text[1]=='' then
            vim.notify('No text selected',vim.log.levels.WARN)
            return
        end
        ranges=require'iedit.finder'.find_all_ocurances(0,text)
    else
        ranges=require'iedit.selector'.start(range,M.config.select)
    end
    require'iedit.iedit'.start(ranges,M.config)
end

function M.select_all()
    M.select{all=true}
end

function M.stop(id,buf)
    local ns=require'iedit.iedit'.ns
    buf=buf or 0
    local data=vim.b[buf].iedit_data or {}
    local ids
    if id then
        ids={[tostring(id)]=data[tostring(id)]}
    else
        ids=data
    end
    for key,marks in pairs(ids) do
        for _,mark_id in ipairs(marks~=vim.NIL and marks or {}) do
            pcall(vim.api.nvim_buf_del_extmark,buf,ns,mark_id)
        end
        data[key]=nil
    end
    vim.b[buf].iedit_data=data
end

function M.toggle(_opts)
    if vim.tbl_isempty(vim.b.iedit_data or {}) then
        M.select(_opts)
    else
        M.stop()
    end
end

return M
