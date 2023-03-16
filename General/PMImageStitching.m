classdef PMImageStitching
    %PMIMAGESTITCHING to reconstruct a single image from a series of (stitched) subimages;
    
    properties (Access = private)
        ImageMap
        StichtingStructure
    end
    
    methods
        function obj = PMImageStitching(varargin)
            %PMIMAGESTITCHING Construct an instance of this class
            %   Takes 2 arguments:
            % 1: image series
            % 2: stiching structure
            switch length(varargin)

                case 2
                    obj.ImageMap =                          varargin{1};
                    obj.StichtingStructure =                varargin{2};

                otherwise
                    error('Wrong input.')

            end
        end

        function obj = set.ImageMap(obj, Value)

            assert(isa(Value, 'PMImageMap'), 'Wrong input.')
               obj.ImageMap = Value;
        end

        function obj = set.StichtingStructure(obj, Value)

            assert(isa(Value, 'struct'), 'Wrong input.')
            Match = min(strcmp(fieldnames(Value), {'X'; 'Y'}));

            assert(Match == 1, 'Fieldnames of structure do not match.')
            obj.StichtingStructure =        Value;

        end

    end

    methods

         function RawImage = getStitchedImage(obj)
            %GETSTITCHEDIMAGE returns stitched image
            RawImage =                          cast(zeros(1, 1), 'uint8');

            MyImageVolumes =                    arrayfun(@(index) PMImageDirectory(obj.ImageMap(index, :)).getImage, (1 : size(obj.ImageMap, 1) )', 'UniformOutput', false);
            RawImage(MyStichingStructure.Y.TotalSize, MyStichingStructure.X.TotalSize) = 0;
            for imageIndex = 1 : length(MyImageVolumes)
               RawImage(1 + MyStichingStructure.Y.Shifts(imageIndex) : MyStichingStructure.Y.PanelSizes(imageIndex) + MyStichingStructure.Y.Shifts(imageIndex), ...
                        1 + MyStichingStructure.X.Shifts(imageIndex) : MyStichingStructure.X.PanelSizes(imageIndex) + MyStichingStructure.X.Shifts(imageIndex)) =             ...
                        MyImageVolumes{imageIndex};
            
            end

           
        end



    end

    
end

