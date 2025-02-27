return function(glsl3code)
    local text = glsl3code..""

    if love.graphics.getSupported().glsl3 then
        text = text:gsub("_ADDITIONAL_","")
        return text
    end
    if text:find("#pragma language glsl3") then
        local tokens = {""}
        local groups = {
            " \n",
            "{}()[];,",
            "+*/=",
            "><&|%"
        }
        for i = 1, #groups do
            local l = groups[i]
            local t = {}
            for j = 1, #l do
                t[string.sub(l,j,j)] = true
            end
            groups[i] = t
        end

        local cg = 1
        local comment;
        for i = 1, #text do
            local c = string.sub(text,i,i)

            if comment then
                if c=="\n" then
                    comment = false
                end
            else
                local g = 0
                for j = 1, #groups do
                    if groups[j][c] then
                        g = j
                        if g == 2 then
                            g = i+#groups
                        end
                        break
                    end
                end
    
                if g~=1 then                    
                    if cg==g then
                        tokens[#tokens] = tokens[#tokens]..c
                        if tokens[#tokens] == "//" then 
                            comment = true 
                            table.remove(tokens,#tokens)
                        end
                    else
                        table.insert(tokens,c)
                    end
                end
                cg = g+0
            end

        end

        for k, v in pairs(tokens) do
            if v=="uint" then
                tokens[k] = "int"
            elseif string.sub(v,1,#v-1)=="uvec" then
                tokens[k] = "ivec"..string.sub(v,#v,#v)
            else
                local n = tonumber(string.sub(v,1,#v-1))
                if n and string.sub(v,#v,#v) == "u" then
                    tokens[k] = string.format("int(%d)",n)
                end
            end

        end


        local replace = {
            [">>"] = "bitshiftr(%s, %s)",
            ["<<"] = "bitshiftl(%s, %s)",
            ["&"] =  "bitand(%s, %s)",
            ["|"] =  "bitor(%s, %s)",
            ["%"] =  "mod(%s, %s)",
        }
        local count = 0
        for k, v in pairs(tokens) do
            count = count+((replace[v] and 1) or 0)
        end


        local limit = 200
        while count>0 and limit>0 do
            local maxlevel = 0
            local maxleveli = 0
            local level = 0
            for k, v in pairs(tokens) do
                level = level + (v=="(" and 1 or 0) - (v==")" and 1 or 0)
                if maxlevel<level then
                    maxleveli = k
                    maxlevel = level+0
                end
            end

            local t = {}
            local i = 0
            while maxleveli>0 do
                table.insert(t,tokens[maxleveli+i])
                if tokens[maxleveli+i] == ")" then break end
                if not tokens[maxleveli+i] then break end
                i = i+1
            end
            for i = #t-1, 1, -1 do
                table.remove(tokens,maxleveli+i)
            end
            
            if t[1] == "(" and replace[t[3]] and t[5] == ")" then
                print(inspect(t))
                tokens[maxleveli] = string.format(replace[t[3]],t[2],t[4])
                count = count-1
            else
                tokens[maxleveli] = table.concat(t," ")
            end

            limit = limit-1
        end

        

        text = table.concat(tokens," ")
        text = text:gsub("#pragma language glsl3","")
        text = text:gsub(";",";\n")
        text = text:gsub("_ADDITIONAL_",[[
            float log2(float x) {
                return log(x) / log(2.0);
            }
            int bitand(int a, int b) {
                    int result = 0;
                    int n = 1;

                    while (a > 0 || b > 0) {
                        int ba = int(mod(a, 2));
                        int bb = int(mod(b, 2));

                        result += int((ba * bb) * n);

                        a /= 2;
                        b /= 2;

                        n *= 2;
                    }

                    return result;
            }
            int bitor(int a, int b) {
                    int result = 0;
                    int n = 1;

                    while (a > 0 || b > 0) {
                        int ba = int(mod(a, 2));
                        int bb = int(mod(b, 2));

                        result += int((max(ba, bb)) * n);

                        a /= 2;
                        b /= 2;

                        n *= 2;
                    }

                    return result;
            }
            int bitshiftl(int a, int b) {
                return int(float(a) * pow(2.0, float(b)));
            }
            int bitshiftr(int a, int b) {
                return int(float(a) / pow(2.0, float(b)));
            }
        ]])

        return text
    end
end