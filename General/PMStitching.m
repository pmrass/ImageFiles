classdef PMStitching
    %PMSTITCHING To manipulate stiching-info
    
    properties (Access = private)
        StitchingStructure
    end
    
    methods
        function obj = PMStitching(varargin)
            %PMSTITCHING Construct an instance of this class
            %   Detailed explanation goes here
            switch length(varargin)

                case 1
                    obj.StitchingStructure = varargin{1};

                otherwise
                    error('Wrong input.')


            end
        end
        
        function Structure = getStichingStrcutureForChannelIndex(obj, ChannelIndex)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
           
        end
    end
end

