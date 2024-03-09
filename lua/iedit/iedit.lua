local M={}
M.ns=vim.api.nvim_create_namespace'iedit'
M.id=1
function M.mark_id_to_range(buf,mark_id)
    local mark=vim.api.nvim_buf_get_extmark_by_id(buf,M.ns,mark_id,{details=true})
    return {mark[1],mark[2],mark[3].end_row,mark[3].end_col}
end
function M.set_extmark(buf,range,hl,id,constricted)
    return vim.api.nvim_buf_set_extmark(buf,M.ns,range[1],range[2],{
        end_line=range[3],
        end_col=range[4],
        hl_group=hl,
        end_right_gravity=not constricted,
        right_gravity=not not constricted,
        id=id,
    })
end
function M.create_extmarks(buf,ranges,highlight)
    local extmarks={}
    for _,range in ipairs(ranges) do
        table.insert(extmarks,M.set_extmark(buf,range,highlight))
    end
    return extmarks
end
function M.start(ranges,config)
    local buf=vim.api.nvim_get_current_buf()
    if #ranges==0 then
        vim.notify('No ranges selected',vim.log.levels.WARN)
        return
    end
    local old_text=table.concat(vim.api.nvim_buf_get_text(buf,ranges[1][1],ranges[1][2],ranges[1][3],ranges[1][4],{}),'\n')
    local b=vim.b[buf]
    local id=tostring(M.id)
    M.id=M.id+1
    if not b.iedit_data then
        b.iedit_data={}
    end
    local function get()
        return b.iedit_data[id]
    end
    local function set(val)
        local data=b.iedit_data
        data[id]=val
        b.iedit_data=data
    end
    set(M.create_extmarks(buf,ranges,config.highlight))
    local au
    au=vim.api.nvim_create_autocmd({'TextChanged','TextChangedI','TextChangedP'},{
        group=vim.api.nvim_create_augroup('Iedit',{clear=false}),
        buffer=0,
        callback=function()
            if get()==nil then
                vim.api.nvim_del_autocmd(au)
                return
            end
            local all_same=true
            local new_text=nil
            for _,mark_id in pairs(get()) do
                local range=M.mark_id_to_range(buf,mark_id)
                local s,text=pcall(vim.api.nvim_buf_get_text,buf,range[1],range[2],range[3],range[4],{})
                if s and not new_text and table.concat(text,'\n')~=old_text then
                    new_text=text
                elseif s and (not new_text or table.concat(text,'\n')~=table.concat(new_text,'\n')) then
                    all_same=false
                end
                if new_text and not all_same then
                    break
                end
            end
            if not new_text then return end
            old_text=table.concat(new_text,'\n')
            if vim.fn.undotree(buf).seq_cur~=vim.fn.undotree(buf).seq_last then
                return
            end
            if all_same then return end
            vim.cmd.undojoin()
            for _,mark_id in pairs(get()) do
                local range=M.mark_id_to_range(buf,mark_id)
                M.set_extmark(buf,range,config.highlight,mark_id,true)
            end
            for _,mark_id in pairs(get()) do
                local range=M.mark_id_to_range(buf,mark_id)
                vim.api.nvim_buf_set_text(buf,range[1],range[2],range[3],range[4],new_text)
                M.set_extmark(buf,
                    {range[1],range[2],range[1]+#new_text-1,(#new_text==1 and range[2] or 0)+#new_text[#new_text]},
                    config.highlight,mark_id,true)
            end
            for _,mark_id in pairs(get()) do
                local range=M.mark_id_to_range(buf,mark_id)
                M.set_extmark(buf,range,config.highlight,mark_id)
            end
        end
    })
end
return M
