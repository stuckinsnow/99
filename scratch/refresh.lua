R("99")

function fizz_buzz(count)
    local result = {}
    for i = 1, count do
        if i % 15 == 0 then
            table.insert(result, "FizzBuzz")
        elseif i % 3 == 0 then
            table.insert(result, "Fizz")
        elseif i % 5 == 0 then
            table.insert(result, "Buzz")
        else
            table.insert(result, i)
        end
    end
    return result
end

--- @param numbers number[]
function sort(numbers)
    table.sort(numbers)
    return numbers
end
