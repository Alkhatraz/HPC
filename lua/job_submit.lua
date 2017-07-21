#!/usr/bin/lua


--[[
Simple script for checking time limit requirements in slurm.
Some code pulled from https://gist.github.com/treydock/b964c5599fd057b0aa6a and the script that that script references
Main idea - check the partitions max timelimit and enforce it
Also, check that jobs under 7 days dont go to the long partition.

Author: alk_
GNU General Public license
--]]

--General information for making you own slurm job_submit.lua plugins
--I found these out the hard way

--First you have to build the RPMS with the flag --with-lua. This will generate a lua rpm. Needed only on the head node

--Arguments for the 2 builtin functions are important
--slurm.log_user only works when it returns slurm.FAILURE, useful for verbose messages to users
--https://searchcode.com/codesearch/view/74500288/ for list of subfields in job_desc and part_list #Holy hell was this hard to find. Probably better to pull from their github for newer values
--https://github.com/SchedMD/slurm/blob/master/src/plugins/job_submit/lua/job_submit_lua.c
--slurm.log_debug will log into slurm log and the debug log which is accessible over slurmctld -Dvvvvv , print() also logs there.
--Slurm API documentation is bad

SLURM_INVALID_TIME_LIMIT = 2051;

function default_partition(part_list)
    -- Return the name of the default partition
    -- part_list	: list of partitions

    for name, part in pairs(part_list) do
        if part.flag_default == 1 then
            return name
        end
    end
end

function get_partition(part_list, name)
    -- Return the partition matching name
    -- part_list	: list of partitions
    -- name : partition name

    for part_name, part in pairs(part_list) do
        if part_name == name then
            return part
        end
    end
end


function check_part_timelimit(part_list, partitions, req_time)
    --This will check the submited list of partitions and see if any are invalid
    --@return - 0 if OK, partition name for failed check
    --lua pattern = [] match a character class, or a char, ^says to ignore, + says as many times as possible
    --Equal to split(partitions, ","), but lua has no split
    for name in string.gmatch(partitions, '[^,]+')do
        print(name)
        if(get_partition(part_list,name).max_time < req_time) then
            return name
        end
    end
    return 0
end

function check_default_timelimit(part_list, time_limit)
    --@return - true if it passes check, false if requested is more than default
    return get_partition(part_list,default_partition(part_list)).max_time >= time_limit
end

function too_short_for_long(partitions,time_limit)
    --This function checks whether the requested time limit is less than 7 days and if the requested job
    --contains the partition 'long'
    --this is so that short jobs dont kill the long queue
    --10080 is 7 days in minutes
    --@return - 0 on success, 1 on failure

    if(time_limit < 10080)then
        for name in string.gmatch(partitions, '[^,]+')do
            if(name == "long") then
                return 1
            end
        end
    end
    return 0
end

function slurm_job_submit(job_desc, part_list, submit_uid)

    --This makes sure that programs run in --pty mode, for quick bash scripting on the default cluster with minimal resources pass from the time check
    --pty sets IO to /dev/null, or in luas case nil
    if(job_desc.std_in == nil and job_desc.std_out == nil) then
        return slurm.SUCCESS
    end


    --Default cant be long partition.
    if (job_desc.partition ~= nil) then

        if(too_short_for_long(job_desc.partition, job_desc.time_limit) == 1) then
            slurm.log_user("You have requested the partition 'long' for your job, but it is not allowed to run jobs that take less than 7 days in the 'long' partition. Please use a different partition for your job.")
            return SLURM_INVALID_TIME_LIMIT
        end

        check = check_part_timelimit(part_list, job_desc.partition, job_desc.time_limit)
        if(check == 0) then
            return slurm.SUCCESS
        else
            s = "You have requested too much time or specified no time limit for your job to run on a partition. Maximum for partition '" .. check .. "' is " .. get_partition(part_list,check).max_time .. " minutes and you requested " .. job_desc.time_limit .. " minutes"
            slurm.log_user(s)
            return SLURM_INVALID_TIME_LIMIT
        end
    else
        --fallback for default partition
        if(check_default_timelimit(part_list, job_desc.time_limit)) then
             return slurm.SUCCESS
        end

        s = "You have requested too much time or specified no time limit for your job to run on the default partition. The maximum timelimit for the default partition is " .. get_partition(part_list,default_partition(part_list)).max_time  .. " minutes and you requested " .. job_desc.time_limit .. " minutes"
        slurm.log_user(s)
        return SLURM_INVALID_TIME_LIMIT
    end

    return slurm.SUCCESS
end


function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
    --We skip job_modify because user cant modify existing jobs. Adding restrictions here will only make it harder for administrators to change job parameters
    return slurm.SUCCESS
end
