classdef PMTIFFLSMDocument
    %PMTIFFLSMDOCUMENT Takes care of special aspects of "lsm" type TIFF file;
    % this object is typically used by PMTIFFDocument objects to help them interpret lsm files;
    
    properties (Access = private)
        NumberOfImages
        NumberOfFrames
        NumberOfPlanes
    end
    
    methods
        function obj = PMTIFFLSMDocument(varargin)
            %PMTIFFLSMDOCUMENT Construct an instance of this class
            %   Takes 3 arguments:
            % 1: number of images
            % 2: number of frames
            % 3: number of planes
          
            switch length(varargin)
                
                case 3
                    obj.NumberOfImages = varargin{1};
                    obj.NumberOfFrames = varargin{2};
                    obj.NumberOfPlanes = varargin{3};
                    
                otherwise
                    error('Wrong input.')
                
                
            end
            
        end
        
        function OrderOfImages = getImageOrderMatrix(obj)
            %GETIMAGEORDERMATRIX returns matrix with image order of image file directories;
              NumberOfChannels=                       1; % there may be multiple channels but they are within each IFD and don't count here

                    OrderOfImages=                          nan(obj.NumberOfImages,3);


                    %% get list of planes:
                    ListWithPlanes=                         repmat((1:obj.NumberOfPlanes)',1,obj.NumberOfFrames);
                    ListWithPlanes=                         reshape(ListWithPlanes, numel(ListWithPlanes), 1);

                    %% based on number of planes/frames/channels: get list with time-frames
                    ListWithTimeFrames =                    1:obj.NumberOfFrames;
                    ListWithTimeFramesForAllIFD =           repmat(ListWithTimeFrames,obj.NumberOfPlanes*NumberOfChannels,1);
                    ListWithTimeFramesForAllIFD=            reshape(ListWithTimeFramesForAllIFD, numel(ListWithTimeFramesForAllIFD), 1);

                    %OrderOfImages(:,1)=                     nan;   % channel remains nan (no relevant information here; all channels get filled up for each IFD) ;
                    OrderOfImages(:,2)=                     ListWithPlanes;      % Z;      
                    OrderOfImages(:,1)=                     ListWithTimeFramesForAllIFD;                    
                   
        end
    end
end

