classdef Simulator < handle
%% SIMULATOR is responsible for stepping the program through the simulation.
%
% Simulator Properties:
%   parent          - AppWindow graphics handle
%   clock           - Global timer for the simulation
%   time_step       - Time step for the simulation
%   split           - Split between calls to step()
%
% Simulator Methods:
%   step            - Executes one time step of the simulation.
%   start           - Starts the simulation.
%   stop            - Stops the simulation.

% Copyright (C) 2013, Georgia Tech Research Corporation
% see the LICENSE file included with this software

    properties
        %% PROPERTIES
        
        parent          % AppWindow graphics handle
        clock           % Global timer for the simulation
        time_step       % Time step for the simulation
        
        world           % A virtual world for the simulator
        physics
        
        origin
    end
    
    methods
        %% METHODS
        
        function obj = Simulator(parent, world, time_step, origin)
        %% SIMULATOR Constructor
        %   obj = Simulator(parent, time_step) is the default constructor
        %   that sets the graphics handle and the time step for the
        %   simulation.
        
            obj.parent = parent;
            obj.time_step = time_step;
            if(strcmp(origin, 'launcher') || strcmp(origin, 'hardware'))
                obj.clock = timer('Period', obj.time_step, ...
                                  'TimerFcn', @obj.step, ...
                                  'ExecutionMode', 'fixedRate', ...
                                  'StartDelay', obj.time_step);
            else
                obj.clock = [];
            end
            obj.world = world;
            obj.physics = simiam.simulator.Physics(world);
            obj.origin = origin;
            
%             %% fill vector in supervisor with info of targets.....
%             % ........................................................start
%             token_k = world.targets.head_;
%             i=1;
%             while (~isempty(token_k))
%                 target = token_k.key_;
%                 obj.world.robots.head_.key_.supervisor.goal(1,i) = target.pose.x;
%                 obj.world.robots.head_.key_.supervisor.goal(2,i) = target.pose.y;
%                 %obstacles.supervisor.execute(split);
%                 token_k = token_k.next_;
%                 i=i+1;
%             end
%             % fill vector in supervisor with info of targets......
%             % ........................................................done
            
            
        end
        
        function step(obj, src, event)
        %% STEP Executes one time step of the simulation.
        %   step(obj, src, event) is the timer callback which is executed
        %   once every time_step seconds.
        
%             if(strcmp(obj.origin, 'launcher'))
%                 split = obj.time_step;
%             else
%                 split = max(obj.time_step,get(obj.clock, 'InstantPeriod'));
%             end

            split = obj.time_step;
%             fprintf('***TIMING***\nsimulator split: %0.3fs, %0.3fHz\n', split, 1/split);
            
%             tstart = tic;
            nRobots = length(obj.world.robots);
            for k = 1:nRobots
                robot_s = obj.world.robots.elementAt(k);
                
                if (strcmp(obj.origin, 'hardware'))
                    pose_k_1 = robot_s.robot.update_state_from_hardware(robot_s.pose, split);
                    [x, y, theta] = pose_k_1.unpack();
                else
                    [x, y, theta] = robot_s.robot.update_state(robot_s.pose, split).unpack();
                end
                robot_s.pose.set_pose([x, y, theta]);
%                 fprintf('current_pose: (%0.3f,%0.3f,%0.3f)\n', x, y, theta);
                
                robot_s.supervisor.execute(split);
            end
%             fprintf('controls: %0.3fs\n', toc(tstart));
            
            %mfu edit
            %% update dynamic obstacles position...........................
            % ........................................................start
            token_mfu = obj.world.obstacle_dyn.head_;
            ii=1;
            while (~isempty(token_mfu))
                obstacle_dyn_current = token_mfu.key_;
                [x_dyn_obs, y_dyn_obs, theta_dyn_obs] = obstacle_dyn_current.obstacle_dyn.update_state(obstacle_dyn_current.pose, split).unpack();%unpack because the output is pose 
                obstacle_dyn_current.pose.set_pose([x_dyn_obs, y_dyn_obs, theta_dyn_obs]);
              
                token_mfu = token_mfu.next_;%go to next dyn obstacle
                ii= ii+ 1;
            end%while
            % update dynamic obstacles position............................
            % .........................................................done



%             tstart = tic;
            if strcmp(obj.origin, 'simulink')
                % skip
            else
                anApp = obj.world.apps.elementAt(1);
                anApp.run(split);
            end
%             fprintf('app: %0.3fs\n', toc(tstart));
            
%             tstart = tic;
%             if(~obj.islinked)
            if (strcmp(obj.origin, 'launcher') || strcmp(obj.origin, 'testing'))
                bool = obj.physics.apply_physics();
            else
                bool = false;
            end
%             else
%                 bool = false;
%             end
%             fprintf('physics: %0.3fs\n', toc(tstart));
            
%             tstart = tic;
            obj.parent.ui_update(split, bool);
            drawnow;
%             fprintf('ui: %0.3fs\n', toc(tstart));
%             fprintf('loop: %0.3fs\n', toc(tstart));
        end
        
        function start(obj)
        %% START Starts the simulation.
            if (strcmp(obj.origin, 'launcher') || strcmp(obj.origin, 'hardware'))
                start(obj.clock);
            end
        end
        
        function stop(obj)
        %% STOP Stops the simulation.
            if strcmp(obj.origin, 'launcher')
                stop(obj.clock);
            elseif strcmp(obj.origin, 'hardware')
                stop(obj.clock);
                nRobots = length(obj.world.robots);
                for k = 1:nRobots
                    robot_s = obj.world.robots.elementAt(k);
                    robot_s.robot.close_hardware_link();
                end
            end
        end
        
        function shutdown(obj)
            obj.stop();
            if strcmp(obj.origin, 'launcher')
                delete(obj.clock);
            elseif strcmp(obj.origin, 'hardware')
                delete(obj.clock);
                nRobots = length(obj.world.robots);
                for k = 1:nRobots
                    robot_s = obj.world.robots.elementAt(k);
                    delete(robot_s.robot.driver.socket);
                end
            end
        end
    end
    
end
