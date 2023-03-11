classdef PMTimeCalibrationSeries
    %PMTIMECALIBRATIONSERIES Summary of this class goes here
    %   allows management of time calibrations-series
    
    properties
        Calibrations =  PMTimeCalibration
    end
    
    methods
        
        function obj = PMTimeCalibrationSeries(varargin)
            %PMSPACECALIBRATIONSERIES Construct an instance of this class
            % takes 0 or 1 arguments:
            % 1: vector of 'PMTimeCalibration' objects
            NumberOfInputArguments =     length(varargin);
            switch NumberOfInputArguments
                case 0
                case 1
                    obj.Calibrations = varargin{1};
            end
        end
        
         function obj = set.Calibrations(obj,Value)
            assert(isa(Value, 'PMTimeCalibration') && isvector(Value), 'Wrong input format.')
            obj.Calibrations =  Value;
         end 
         
    end
    
    methods % GETTERS
        
        function number = getNumberOfFrames(obj)
            number = sum(arrayfun(@(x) x.getNumberOfFrames, obj.Calibrations));

        end

        function frames = getTimeStampsInSeconds(obj)
            % GETTIMESTAMPSINSECONDS returns list of time-stamps in seconds;
            % returns 1 value:
            % 1: numerical vector
            frames = arrayfun(@(x) x.getTimeStampsInSeconds, obj.Calibrations, 'UniformOutput', false);
            frames = vertcat(frames{:});
        end

        function frames = getRelativeTimeStampsInSeconds(obj)
           frames = obj.getTimeStampsInSeconds;
           frames = frames - frames(1);
        end
        
    end
    
    methods % PROCESSING
        
        function frames_Seconds = convertFramesIntoSeconds(obj, list)
             if iscell(list)
                    TimeInSeconds =     obj.getTimeStampsInSeconds;
                    frames_Seconds =    num2cell(TimeInSeconds(cell2mat(list)));
             else
                 error('Input type not supported.')
             end
        end

        function frames_Minutes = convertFramesIntoMinutes(obj, list)
            if iscell(list)

                TimeInSeconds =     obj.getTimeStampsInSeconds;
                ListWithFrames =    cell2mat(list);
                MyList_Seconds =    TimeInSeconds(ListWithFrames);
                frames_Minutes =    num2cell(MyList_Seconds / 60);
            else
                 error('Input type not supported.')
             end
        end
           
        
        
    end
    
end

