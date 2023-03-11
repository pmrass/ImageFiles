classdef PMTimeCalibration
    %PMTIMECALIBRATION manages time calibration
    %   allows retrieval and conversion of time-stamps
    
    properties (Access = private)
        TimePoints_Seconds
    end
    
    methods
        function obj = PMTimeCalibration(varargin)
            %PMTIMECALIBRATION Construct an instance of this class
            % takes 0 or 1 arguments:
            % 1: numerical vector (containing "time-stamps" in seconds)
            NumberOfInputArguments =    length(varargin);
            switch NumberOfInputArguments
                case 0
                case 1
                    obj.TimePoints_Seconds  =       varargin{1};
                otherwise
                    error('Wrong number of input arguments.')
            end
        end
        
        function obj = set.TimePoints_Seconds(obj,Value)
            assert(isnumeric(Value) && isvector(Value), 'Wrong input format.')
            obj.TimePoints_Seconds =  Value(:);
        end
        
        
        
        
    
      
        
       
        
        
    end
    
    methods % GETTERS
        
         function frames = getTimeStampsInSeconds(obj)
             % GETTIMESTAMPSINSECONDS returns list of time-stamps in seconds;
             % returns 1 value:
             % 1: numerical vector
            frames = obj.TimePoints_Seconds;
         end
         
        function numberOfFrames = getNumberOfFrames(obj)
            numberOfFrames = length(obj.TimePoints_Seconds);
        end
        
        
    end
    
    methods % PROCESSING
        
            function frames_Seconds = convertFramesIntoSeconds(obj, list)
             if iscell(list)
                frames_Seconds =    num2cell(obj.TimePoints_Seconds(cell2mat(list)));
             else
                 error('Input type not supported.')
             end
        end
        
        function frames_Minutes = convertFramesIntoMinutes(obj, list)
            if iscell(list)
                ListWithFrames =    cell2mat(list);
                MyList_Seconds =    obj.TimePoints_Seconds(ListWithFrames);
                frames_Minutes =    num2cell(MyList_Seconds / 60);
            else
                 error('Input type not supported.')
             end
        end
        
    end
    
    
    
end

