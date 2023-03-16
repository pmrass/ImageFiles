classdef PMImageMap
    %PMIMAGEMAP for convenient accessing data of ImageMap cells or structures;
    
    properties (Access = private)
        RawData
    end
    
    properties (Access = private)
       
        NumberOfColumns = 17
        
        ColumnTitles = { ...,
        'ListWithStripOffsets', ... % 1
        'ListWithStripByteCounts', ... % 2
        'FilePointer', ... % 3
        'ByteOrder', ... % 4
        'BitsPerSample', ... % 5
        'Precisision', ... % 6
        'SamplesPerPixel', ... % 7
        'TotalColumnsOfImage', ... % 8
        'TotalRowsOfImage', ... % 9
        'TargetFrameNumber', ... % 10
        'TargetPlaneNumber', ... % 11
        'RowsPerStrip', ... % 12
        'TargetStartRows', ... % 13
        'TargetEndRows', ... % 14
        'TargetChannelIndex', ... % 15
        'PlanarConfiguration', ...
        'CompressionType', ...
        };

        
        
    end
    
    properties (Access = private, Constant)
        
        OffsetColumn = 11;
        OffsetByteColumn = 2;
        FilePointerColumn = 3;
        ByteOrderColumn = 4;
        BitsPerSampleColumn = 5;
        PrecisionColumn = 6;
        SamplesPerPixelColumn = 7;
        
        ImageColumnsColumn = 8;
        ImageRowsColumn = 9;
        FrameColumn = 10;
        PlaneColumn = 11;
        RowsPerStripColumn = 12;
        TargetStartRows = 13;
        TargetEndRows = 14;
        TargetChannelIndex = 15;
        PlanarConfigurationColumn = 16;
        CompressionColumn = 17;
        
         
    end
    
    methods
        
        function obj = PMImageMap(varargin)
            %PMIMAGEMAP Construct an instance of this class
            %   takes 0, or 1 arguments;
            % 1: cell matrix with 17 columns: first row titles: other rows: data;
            % 2: structure that contains data just for a single row;
            
            switch length(varargin)
               
                case 0
                    
                case 1
                    
                    switch class(varargin{1})
                        
                       
                        case 'cell'
                            Input = varargin{1};

                                assert(iscell(Input) && ismatrix(Input) && size(Input, 1) >= 2 && size(Input, 2) == 17, 'Image map has wrong size.')
                            
                                switch class(Input{1,1})

                                    case 'char'
                                         obj.RawData = Input(2:end, :);

                                    case 'uint32'
                                           obj.RawData = Input(:, :);  

                                    otherwise
                                        error('Invalid image map.')


                                end
                                
                        case 'struct'
                            
                            FieldsForImageReading = varargin{1};
                            
                            obj.RawData{2, 1} = FieldsForImageReading.ListWithStripOffsets;
                            obj.RawData{2, 2} = FieldsForImageReading.ListWithStripByteCounts;
                            obj.RawData{2, 3} = FieldsForImageReading.FilePointer;
                            obj.RawData{2, 4} = FieldsForImageReading.ByteOrder;
                            obj.RawData{2, 5} = FieldsForImageReading.BitsPerSample;
                            obj.RawData{2, 6} = FieldsForImageReading.Precisision;
                            obj.RawData{2, 7} = FieldsForImageReading.SamplesPerPixel;
                            obj.RawData{2, 8} = FieldsForImageReading.TotalColumnsOfImage;
                            obj.RawData{2, 9} = FieldsForImageReading.TotalRowsOfImage;
                            obj.RawData{2, 10} = FieldsForImageReading.TargetFrameNumber;
                            obj.RawData{2, 11} = FieldsForImageReading.TargetPlaneNumber;
                            obj.RawData{2, 12} = FieldsForImageReading.RowsPerStrip;
                            obj.RawData{2, 13} = FieldsForImageReading.TargetStartRows;
                            obj.RawData{2, 14} = FieldsForImageReading.TargetEndRows;
                            obj.RawData{2, 15} = FieldsForImageReading.TargetChannelIndex;
                            obj.RawData{2, 16} = FieldsForImageReading.PlanarConfiguration;
                            obj.RawData{2, 17} = FieldsForImageReading.Compression;
                            
                            
                            
    
                        otherwise
                            error('Wrong input.')
                        
                        
                    end
                    
                    
                otherwise
                    error('Wrong input.')
                
                
            end
            
          
        end
        
    
    end

    methods % SETTERS

        function obj = setFileName(obj, FileName)

            obj.RawData(:, obj.FilePointerColumn) = {FileName};

        end


    end
    
    methods % GETTERS
        
        function ImageMap = getImageMap(obj)

           ImageMap = [ obj.ColumnTitles; obj.RawData];

          

        end


        function matrix =           getCellMatrix(obj)
            % GETCELLMATRIX returns cell matrix with contents of image map (without column-titles);
            matrix = obj.RawData(2: end, :);
        end

        function PooledMaps =           getCellMatrixForChannel(obj, ChannelIndex)
            % GETCELLMATRIX returns cell matrix with contents of image map (without column-titles);
               matrix =           obj.getCellMatrix;
           
            WantedRows =                cell2mat(matrix(:, 15)) == ChannelIndex;
            PooledMaps =                  matrix(WantedRows, :);
         end

        
        function Titles =           getTitles(obj)
            % GETTITLES returns column titles
            Titles = obj.ColumnTitles;
            
        end
        
        function PlaneList =        getMaxPlaneForEachFrame(obj)
            % GETMAXPLANEFOREACHFRAME
            frames = obj.getListOfAllFrames;
            planes = obj.getListOfAllPlanes;
            
            UniqueFrames =  unique(frames);
            PlaneList = zeros(length(UniqueFrames), 1);
            for FrameIndex = 1:length(UniqueFrames)
                
               PlaneList(FrameIndex) =  max(planes(obj.getRowsForFrame(UniqueFrames(FrameIndex))));
                
            end
          
         end
        
        function rowsForFrame =     getRowsForFrame(obj, Frame)
            % GETROWSFORFRAME returns row indices for ;
            rowsForFrame = obj.getListOfAllFrames == Frame;
            
        end
             
   
    end
    
    methods % PROCESSSING
        
        function ImageMap = getCompletedImageMap(obj, ImageMap)
            % GETCOMPLETEDIMAGEMAP adds missing columns to image map;
            % adds default PlanarConfigurationColumn and CompressionType;
            assert(size(ImageMap, 1) >= 2, 'Wrong format.')
             switch size(ImageMap, 2)
                 case 15
                     ImageMap(1, 1 : obj.NumberOfColumns) =                 obj.ColumnTitles;
                     ImageMap(2 : end, obj.PlanarConfigurationColumn) =     {NaN};
                     ImageMap(2 : end, obj.CompressionColumn) =     {'NoCompression'};
                     
                     
                 case 17
                     
                 otherwise
                     error('Number of columns not supported.')
                 
                 
             end
        end
        
        
    end
    
    methods (Access = private)
        
        function frames =       getListOfAllFrames(obj)
             frames = cell2mat(obj.RawData(:, obj.FrameColumn));
        end
        
        function frames =       getListOfAllPlanes(obj)
             frames = cell2mat(obj.RawData(:, obj.PlaneColumn));
        end
         
   
        
    end
    
end

