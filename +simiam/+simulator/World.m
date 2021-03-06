classdef World < handle
    
% Copyright (C) 2013, Georgia Tech Research Corporation
% see the LICENSE file included with this software
% Modifications by Marcus Futterlieb

    properties
        robots
        obstacles
        parent
        apps
        root_path
        
        %mfu edit
        obstacle_dyn
        target
    end
    
    methods
        function obj = World(parent)
            obj.parent = parent;
            obj.robots = simiam.containers.ArrayList(10);
            obj.obstacles = mcodekit.list.dl_list();
            obj.apps = simiam.containers.ArrayList(10);
            obj.root_path = '';
            
            %mfu edit
            obj.obstacle_dyn = mcodekit.list.dl_list();
            obj.target = mcodekit.list.dl_list();
        end
        
        function build_from_file(obj, root, file, origin)
            
            % Read in XML file
            blueprint = xmlread(file);
            obj.root_path = root;
            
            % Parse XML file for robot configurations
            app_list = blueprint.getElementsByTagName('app').item(0);
            app = char(app_list.getAttribute('type'));
            
            r = str2func(strcat('simiam.app.', app));
            obj.apps.appendElement(r(root));
            
            
            % Parse XML file for target configurations
            target_list = blueprint.getElementsByTagName('target');
            %             xValues = [];
            %             yValues = [];
            for i = 0:(target_list.getLength-1)
                target = target_list.item(i);

                pose = target.getElementsByTagName('pose').item(0);
                x = str2double(pose.getAttribute('x'));
                y = str2double(pose.getAttribute('y'));
                theta = str2double(pose.getAttribute('theta'));
                
                % put all targets from setting file into the robot
                % supervisor
%                 obj.robots.head_.key_.supervisor.targets(1,end+1) = x;
%                 obj.robots.head_.key_.supervisor.targets(2,end)   = y;

                obj.add_target(x, y, theta);
            end

            
            
            
            if(strcmp(origin, 'launcher') || strcmp(origin, 'testing') || strcmp(origin, 'hardware'))
            
                robot_list = blueprint.getElementsByTagName('robot');

                for k = 0:(robot_list.getLength-1)
                   robot = robot_list.item(k);

                   type = char(robot.getAttribute('type'));

                   s = robot.getElementsByTagName('supervisor').item(0);
                   spv = char(s.getAttribute('type'));

                   pose = robot.getElementsByTagName('pose').item(0);
                   x = str2double(pose.getAttribute('x'));
                   y = str2double(pose.getAttribute('y'));
                   theta = str2double(pose.getAttribute('theta'));         

                   r = obj.add_robot(type, spv, x, y, theta);
                   
                   driver = robot.getElementsByTagName('driver').item(0);
                   if(~isempty(driver) && strcmp(origin, 'hardware'))
                       hostname = char(driver.getAttribute('ip'));
                       port = str2double(driver.getAttribute('port'));
                       r.add_hardware_link(hostname,port);
                       r.open_hardware_link();
                   end
                end
            end
            
            % Parse XML file for obstacle configurations
            obstacle_list = blueprint.getElementsByTagName('obstacle');
            
            for i = 0:(obstacle_list.getLength-1)
               obstacle = obstacle_list.item(i);
               
               pose = obstacle.getElementsByTagName('pose').item(0);
               x = str2double(pose.getAttribute('x'));
               y = str2double(pose.getAttribute('y'));
               theta = str2double(pose.getAttribute('theta'));
               
               geo = obstacle.getElementsByTagName('geometry').item(0);
               point_list = geo.getElementsByTagName('point');
               
               obstacle_geometry = zeros(point_list.getLength, 2);
               for j=0:(point_list.getLength-1)
                  point = point_list.item(j);
                  obstacle_geometry(j+1,1) = str2double(point.getAttribute('x'));
                  obstacle_geometry(j+1,2) = str2double(point.getAttribute('y'));
               end
               
               obj.add_obstacle(x, y, theta, obstacle_geometry);
            end
            
            %mfu edit
            % Parse XML file for dynamic obstacles configurations
            obstacle_dyn_list = blueprint.getElementsByTagName('obstacle_dyn');
            for i = 0:(obstacle_dyn_list.getLength-1)
                obstacle_dyn = obstacle_dyn_list.item(i);

                pose        = obstacle_dyn.getElementsByTagName('pose').item(0);
                x           = str2double(pose.getAttribute('x'));
                y           = str2double(pose.getAttribute('y'));
                theta       = str2double(pose.getAttribute('theta'));
                
                
                movement    = obstacle_dyn.getElementsByTagName('movement').item(0);
                direction   = str2double(movement.getAttribute('direction'));
                speed       = str2double(movement.getAttribute('speed'));
                radius      = str2double(movement.getAttribute('radius'));
                type        = movement.getAttribute('type');
                
                theta       = direction;
                
                geo = obstacle_dyn.getElementsByTagName('geometry').item(0);
                point_list = geo.getElementsByTagName('point');
               
                obstacle_geometry = zeros(point_list.getLength, 2);
                for j=0:(point_list.getLength-1)
                    point = point_list.item(j);
                    obstacle_geometry(j+1,1) = str2double(point.getAttribute('x'));
                    obstacle_geometry(j+1,2) = str2double(point.getAttribute('y'));
                end
                
                
                
                obj.add_obstacle_dyn(x, y, theta, obstacle_geometry, direction, speed, radius, type);
            end
            
            
            
        end
        
        function aRobot = add_robot(obj, type, spv, x, y, theta)
            pose = simiam.ui.Pose2D(x, y, theta);
            
            r = str2func(strcat('simiam.robot.', type));
            robot = r(obj.parent, pose);
            
            r = str2func(strcat('simiam.controller.', spv));
            supervisor = r();
            
            supervisor.attach_robot(robot, pose);
            
            %            parameter_file = fullfile(obj.root_path, 'parameters.xml');
            %            [file, path, extension] = uigetfile(parameter_file, 'Pick a XML file with the parameters for the PID regulator.');
            %
            %            parameter_file = fullfile(path, file);
            %            supervisor.configure_from_file(parameter_file);
            
            s = struct('robot', robot, 'supervisor', supervisor, 'pose', pose);
            %            obj.robots.append_key(s);
            
            obj.robots.appendElement(s);          
            anApp = obj.apps.elementAt(1);
            anApp.supervisors.appendElement(supervisor);
            
            aRobot = s.robot;
            
            %mfu edit
            if (strcmp(type,'QuickBot')== true)    
                %% fill vector in supervisor with info of targets.....
                % ........................................................start
                token_k = obj.target.head_;
                i=1;
                while (~isempty(token_k))
                    target = token_k.key_;
                    supervisor.target(1,i) = target.pose.x;
                    supervisor.target(2,i) = target.pose.y;
                    %obstacles.supervisor.execute(split);
                    token_k = token_k.next_;
                    i=i+1;
                end
                % fill vector in supervisor with info of targets......
                % ........................................................done    
            end%if
            
        end
        
        function add_obstacle(obj, x, y, theta, geometry)
           pose = simiam.ui.Pose2D(x, y, theta);
           obj.obstacles.append_key(struct('obstacle', simiam.simulator.Obstacle(obj.parent, pose, geometry), 'pose', pose));
        end
        
        %mfu edit
        function add_obstacle_dyn(obj, x, y, theta, geometry, direction, speed, radius, type)
           pose = simiam.ui.Pose2D(x, y, theta);
           obj.obstacle_dyn.append_key(struct('obstacle_dyn', simiam.simulator.Obstacle_dyn(obj.parent, pose, geometry, direction, speed, radius, type), 'pose', pose));
        end
          
        function add_target(obj, x, y, theta)
           pose = simiam.ui.Pose2D(x, y, theta);
           obj.target.append_key(struct('target', simiam.simulator.Target(obj.parent, pose), 'pose', pose));
        end
    end
    
end
