local M={}
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
return M
