classdef PMImageDirectory
    %PMIMAGEDIRECTORY contains information of single "directory" (i.e. single row of Image map);
    %   method drawOnImageVolume allows adding the corresponding image data from file to input image;
    
    properties (Access = private)
        RawData
        
    end
    
    methods % INITIALIZE
        
        function obj = PMImageDirectory(varargin)
            %PMIMAGEDIRECTORY Construct an instance of this class
            % input: 1 argument
            % cell that contains content of 1 row of an image map;
           NumberOfArguments = length(varargin);
           switch NumberOfArguments
               case 1
                   obj.RawData = varargin{1};
               otherwise
                   error('Wrong input.')
               
           end
        end
        
        function obj = set.RawData(obj,Value)
            assert(iscell(Value) && isvector(Value) && length(Value) == 17, 'Wrong input.')
            obj.RawData = Value;
        end
        

    end
    
    methods % GETTERS
        

        function Image = getImage(obj)

            assert(obj.getNumberOfStrips == 1, 'Wrong content.')

            StripData =         obj.readStripsFromFile;
            StripData =         obj.deCompressStripData(StripData);
            StripData =         obj.reshapeStripData(StripData) ; 

            assert(length(StripData) == 1, 'Currently image can be generated only if file has precisely one strip.')
             
            Image  =            StripData{1};

        end

         function ImageVolume = drawOnImageVolume(obj, ImageVolume)
            % DRAWONIMAGEVOLUME adds image data to input volume of all strips of directory;
            % input 5D-image volume
            % output 5D-image volume (after writing image data of file into volume);

            StripData =         obj.readStripsFromFile;
            StripData =         obj.deCompressStripData(StripData);
            StripData =         obj.reshapeStripData(StripData) ; 
             
            for CurrentStripIndex = 1 : obj.getNumberOfStrips
                
                  ImageVolume(...
                            obj.getUpperRowForStripIndex(CurrentStripIndex) : obj.getBottomRowForStripIndex(CurrentStripIndex), ...
                            1 : obj.getNumberOfColumns, ...
                            obj.getPlanes, ...
                            obj.getFrames, ...
                            obj.getChannelForStripIndex(CurrentStripIndex)...
                            )=     StripData{CurrentStripIndex};
                
                
            end
            
         end
            
    end
    
        
    methods % GETTERS BASIC:
        
        function bytesPerSample =   getBytesPerSample(obj)
            bytesPerSample =                    obj.RawData{5}/8; 
        end
        
        function planes =           getPlanes(obj)
            planes =                obj.RawData{11};
        end

        function frame =            getFrames(obj)
            frame =                obj.RawData{10};
        end
        
        function precision =        getPrecision(obj)
            precision =                obj.RawData{6};
         end
        
        function byteOrder =        getByteOrder(obj)
            byteOrder =                obj.RawData{4};
        end

        function columns =          getNumberOfColumns(obj)
            columns =                obj.RawData{8};
        end

        function ChannelList =      getCompressionType(obj)
            ChannelList =                    obj.RawData{17};
         end
        
        function fileID =           getFileID(obj)
            try
                fileID =                fopen(obj.RawData{3});    
            catch
                error('Something went wrong.')
            end
        end
        
    end
    
    methods % GETTERS STRIPS
       
        function stripOffsets =             getStripOffsets(obj)
            stripOffsets =                obj.RawData{1};
        end
        
        function NumberOfStrips =          getNumberOfStrips(obj)
               NumberOfStrips =         size(getStripOffsets(obj),1); 
        end
        
        function byteCounts =               getStripByteCounts(obj)
            byteCounts =                obj.RawData{2};
        end
        
        function ListWithUpperRows =        getTopRowsPerStrip(obj)
            ListWithUpperRows=        obj.RawData{13};
            if length(ListWithUpperRows) ~= obj.getNumberOfStrips
                assert(isscalar(ListWithUpperRows), 'Something wrong with strip-data.')
                ListWithUpperRows(1:obj.getNumberOfStrips,1) = ListWithUpperRows;
            end
        end
        
        function ListWithLowerRows =        getBottomRowsPerStrip(obj)
                ListWithLowerRows=                   obj.RawData{14};
                if length(ListWithLowerRows) ~= obj.getNumberOfStrips
                     assert(isscalar(ListWithLowerRows), 'Something wrong with strip-data.')
                    ListWithLowerRows(1:obj.getNumberOfStrips,1) = ListWithLowerRows;
                end
        end
        
        function ChannelList =              getChannelsPerStrip(obj)
            ChannelList =                    obj.RawData{15};
            if length(ChannelList) ~= obj.getNumberOfStrips
                ChannelList(1:obj.getNumberOfStrips,1) =   ChannelList;
            end
        end
  
    end
    
    
    
    methods (Access = private) % HELPER: DRAWONIMAGEVOLUME

         function StripData =       deCompressStripData(obj, StripData)
             
             switch obj.getCompressionType
                 
                
                 case 'NoCompression'
                     
                     
                 case 'LZW'

                         for CurrentStripIndex = 1 : obj.getNumberOfStrips
                            fprintf('Decompress strip %i of %i.\n', CurrentStripIndex, obj.getNumberOfStrips)
                            myParser =              PMCompression_LZW(StripData{CurrentStripIndex, 1});
                            myParser =              myParser.lzw2norm;
                            StripData{CurrentStripIndex, 1} =      myParser.getUncompressed16Bit;

                         end

                     
                 otherwise
                     error('Compression not supported.')
                 
                 
             end
             
              
              
             
             
         end
         
         function StripData =       reshapeStripData(obj, StripData)
             
             
              StripInput = StripData;
             
              StripData= cell(obj.getNumberOfStrips, 1);
              for CurrentStripIndex = 1 : obj.getNumberOfStrips
              
                        Input = StripInput{CurrentStripIndex, 1};
              
                        StripData{CurrentStripIndex, 1}=        reshape( ...
                                        Input , ...
                                        obj.getNumberOfColumns, ...
                                        obj.getRowsOfStripIndex(CurrentStripIndex), ...
                                        length(obj.getPlanes));   
                                    
                        StripData{CurrentStripIndex, 1} =         permute (StripData{CurrentStripIndex, 1}, [2 1 3]);  % in image rows should come first, but reshape reads columns first that's why a switch is necessary;  

              end
             
             
         end
        
    end
    
    methods (Access = private) % GETTERS STRIPS (PER INDEX);
        
        function rowPerStrip =             getRowsOfStripIndex(obj, Index)
            Bottom = obj.getBottomRowsPerStrip;
            Top = obj.getTopRowsPerStrip;
            rowPerStrip =               Bottom(Index) - Top(Index) + 1;
        end
         
        function CurrentUpperRow =          getUpperRowForStripIndex(obj, Index)
            ListWithUpperRows=          obj.getTopRowsPerStrip;
             CurrentUpperRow =          ListWithUpperRows(Index,1);
        end
        
        function CurrentBottomRow =         getBottomRowForStripIndex(obj, Index)
            ListWithLowerRows=          obj.getBottomRowsPerStrip;
             CurrentBottomRow =                  ListWithLowerRows(Index,1);
        end
        
        function CurrentChannel =           getChannelForStripIndex(obj,  Index)
            ChannelList =       obj.getChannelsPerStrip;
            CurrentChannel =    ChannelList(Index,1);
        end
        
        
    end

    methods (Access = private) % GETTERS: IMAGE DATA FROM FILE:
        
        function StripData =                readStripsFromFile(obj)
             
               StripData= cell(obj.getNumberOfStrips, 1);
            
              for CurrentStripIndex = 1 : obj.getNumberOfStrips
                  StripData{CurrentStripIndex, 1} =     obj.readStripFromFile(CurrentStripIndex);
              end
         end
         
        function CurrentStripData =         readStripFromFile(obj, Index)
            
            switch obj.getCompressionType
               
                case 'NoCompression'
                    MyFileId =                  obj.getFileID;
                    MyOffset =                  obj.getOffsetForStripIndex(Index);
                    Status =                    fseek(MyFileId,             MyOffset, -1);
                     assert(Status == 0, 'Something wrong with the file identifier.')
                    
                     ByteCount  =                obj.getStripLengthForIndex(Index);
                    CurrentStripData =        cast((fread(MyFileId, ByteCount, obj.getPrecision, obj.getByteOrder))', obj.getPrecision);   
                    fclose(MyFileId);
                    
                case 'LZW'
                    CurrentStripData =           obj.getBitSequenceForStripIndex(Index); 
                    
                otherwise
                    error('Compression type not supported.')

            end
            
            % fprintf('%i of %i (t:%i,z:%i,c:%i); ', CurrentStripIndex,NumberOfStrips, min(obj.getFrames), min(obj.getPlanes), min(CurrentChannel))        
        
        end
        
        function BitSequence =              getBitSequenceForStripIndex(obj, Index)

            MyFileId =          obj.getFileID;
            MyOffset =          obj.getOffsetForStripIndex(Index);
            Status =            fseek(MyFileId,  MyOffset, -1);
            assert(Status == 0, 'Something wrong with the file identifier.')
            
            ByteCount  =                obj.getByteCountForStripIndex(Index);
            CurrentStripData =          cast((fread(MyFileId, ByteCount, 'uint8', obj.getByteOrder))', 'uint8');    
            fclose(MyFileId);

            BitSequence=            de2bi(CurrentStripData, 8);
            BitSequence =           transpose(BitSequence);
            BitSequence =           flipud(BitSequence);
            BitSequence =           BitSequence(:);

       end

        function CurrentStripOffset =       getOffsetForStripIndex(obj, Index)
            ListWithStripOffsets =      obj.getStripOffsets;
            CurrentStripOffset =        ListWithStripOffsets(Index,1);
            
        end
        
        function CurrentStripByteCount =    getByteCountForStripIndex(obj, Index)
            ListWithStripByteCounts=    obj.getStripByteCounts;
            CurrentStripByteCount =     ListWithStripByteCounts(Index,1);
        end
        
        function CurrentStripLength =       getStripLengthForIndex(obj, Index)
            CurrentStripLength =                obj.getByteCountForStripIndex(Index) / obj.getBytesPerSample;
            
        end
        
        
        
    end
        
        
end


