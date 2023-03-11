classdef PMMetaData
    %PMMETADATA For conversion of meta-data structure into other formats;
    % can retrieve calibration and navigation objects:
    
    properties (Access = private)
        MetaDataStructure
    end
    
    properties (Constant, Access = private)
       
            ExpectedFieldNames =     {'NumberOfRows'; 'NumberOfColumns'; 'NumberOfPlanes'; 'NumberOfTimePoints'; 'NumberOfChannels'; 'VoxelSizeX'; 'VoxelSizeY'; 'VoxelSizeZ'};
            ExpectedFieldNamesTwo = {'NumberOfRows'; 'NumberOfColumns'; 'NumberOfPlanes'; 'NumberOfChannels'; 'VoxelSizeX'; 'VoxelSizeY'; 'VoxelSizeZ'; 'NumberOfTimePoints'};

            ExpectedContentsForIndividual =   {'EntireMovie';    'TimeStamp';    'RelativeTimeStamp'};
            ExpectedContentsForPooled =      {'EntireMovie';'PooledTimeStamps';  'RelativeTimeStamps'};
        
    end
    
    methods % INITIALIZATION
        
        function obj = PMMetaData(varargin)
            %PMMETADATA Construct an instance of this class
            %   Takes 0, 1, or 9 arguments
            % 1: meta-data structure
            % 9: values for NumberOfRows, NumberOfColumns, NumberOfPlanes, NumberOfTimePoints, NumberOfChannels, VoxelSizeX, VoxelSizeY, VoxelSizeZ, vector of times for frames; 
            NumberOfInputArguments = length(varargin);
            switch NumberOfInputArguments
                case 0
                    
                case 1
                    obj.MetaDataStructure = varargin{1};
                    
                case 9
                    obj.MetaDataStructure = varargin;
                otherwise
                    error('Number of input arguments not supported')
            end
        end
        
        function obj = set.MetaDataStructure(obj,varargin)
            
            Value =                 varargin{:};
            
            NumberOfArguments =     length(Value);
            switch NumberOfArguments
                
                case 1
                     Type =     obj.getMetaDataType(Value);
                    switch Type
                        case {'Individual', 'IndividualTwo'}
                        case {'Pooled', 'PooledTwo'}
                            Value = obj.convertPooledToIndividualMetaMata(Value);
                        otherwise
                            error('Input type not supported.')     
                    end
                    obj.MetaDataStructure =  Value;
                    
                case 9
                    assert(isnumeric(Value{1}) && isscalar(Value{1}), 'Wrong input type')
                    assert(isnumeric(Value{2}) && isscalar(Value{2}), 'Wrong input type')
                    assert(isnumeric(Value{3}) && isscalar(Value{3}), 'Wrong input type')
                    assert(isnumeric(Value{4}) && isscalar(Value{4}), 'Wrong input type')
                    assert(isnumeric(Value{5}) && isscalar(Value{5}), 'Wrong input type')
                    assert(isnumeric(Value{6}) && isscalar(Value{6}), 'Wrong input type')
                    assert(isnumeric(Value{7}) && isscalar(Value{7}), 'Wrong input type')
                    assert(isnumeric(Value{8}) && isscalar(Value{8}), 'Wrong input type')
                    assert(isnumeric(Value{9}) && isvector(Value{9}), 'Wrong input type')
                    assert(length(Value{9}) == Value{4}, 'Wrong input type')
                    
                    myStructure.EntireMovie.NumberOfRows=                              Value{1}; 
                    myStructure.EntireMovie.NumberOfColumns=                           Value{2}; 
                    myStructure.EntireMovie.NumberOfPlanes=                            Value{3};
                    myStructure.EntireMovie.NumberOfTimePoints=                        Value{4};
                    myStructure.EntireMovie.NumberOfChannels=                          Value{5};

                    myStructure.EntireMovie.VoxelSizeX=                                Value{6}; 
                    myStructure.EntireMovie.VoxelSizeY=                                Value{7}; 
                    myStructure.EntireMovie.VoxelSizeZ=                                Value{8};
                    
                    for FrameIndex = 1 : length(Value{9})
                        TimeOfCourrentFrame=                                       Value{9}(FrameIndex);
                        myStructure.TimeStamp(FrameIndex,1)=                TimeOfCourrentFrame;
                        myStructure.RelativeTimeStamp(FrameIndex,1)=        TimeOfCourrentFrame - Value{9}(1);
                    end
            
                    obj.MetaDataStructure = myStructure;
                    
                otherwise
                    error('Wrong input type')
                
   
            end
            
         end
   
    end
    
    methods % GETTERS
        
        function result =       getPMSpaceCalibration(obj)
            result =        PMSpaceCalibration(obj.MetaDataStructure.EntireMovie.VoxelSizeX, obj.MetaDataStructure.EntireMovie.VoxelSizeY, obj.MetaDataStructure.EntireMovie.VoxelSizeZ);
        end
        
        function result =       getPMNavigation(obj)
            result =        PMNavigation(...
                                    obj.MetaDataStructure.EntireMovie.NumberOfRows, ...
                                    obj.MetaDataStructure.EntireMovie.NumberOfColumns, ...
                                    obj.MetaDataStructure.EntireMovie.NumberOfPlanes, ...
                                    obj.MetaDataStructure.EntireMovie.NumberOfTimePoints, ...
                                    obj.MetaDataStructure.EntireMovie.NumberOfChannels...
                                    );
        end
        
        function result =       getPMTimeCalibration(obj)
            result =        PMTimeCalibration(obj.MetaDataStructure.TimeStamp);
        end
        
        function structure =    getMetaDataStructure(obj)
            structure =         obj.MetaDataStructure;
        end
   
    end
    
    methods % PROCESS INPUT
       
         function test = isMetaDataStructure(obj,Value)
                %METHOD1 Summary of this method goes here
                %   Detailed explanation goes here
                try
                    type = obj.getMetaDataType(Value);
                    if strcmp(type, 'Individual') || strcmp(Value, 'Pooled')
                        test = true;
                    else
                        test = false;
                    end
                catch
                   test = false; 
                end
           
        end
        
    end
    
    methods (Access = private) % GETTERS: METADATA VERSION
        
        function type =         getMetaDataType(obj,Value)

            switch class(Value)

                 case 'struct'

                      type = '';
                      MyFieldNames = fieldnames(Value);

                       if isequal(obj.ExpectedContentsForIndividual, MyFieldNames)

                            assert(isstruct(Value.EntireMovie) && isnumeric(Value.TimeStamp) && isnumeric(Value.RelativeTimeStamp), 'Wrong input.')
                            EntireMovieFieldNames =       fieldnames(Value.EntireMovie);
                            if isequal(obj.ExpectedFieldNames, EntireMovieFieldNames)
                                type = 'Individual';

                            elseif isequal(obj.ExpectedFieldNamesTwo, EntireMovieFieldNames)
                                type = 'IndividualTwo';

                            else
                               obj.compareFieldNames(obj.ExpectedFieldNames, EntireMovieFieldNames)
                               error('Meta-data fieldnames do not match.')

                            end

                       elseif isequal(obj.ExpectedContentsForPooled, MyFieldNames)

                               assert(isstruct(Value.EntireMovie) && isnumeric(Value.PooledTimeStamps) && isnumeric(Value.RelativeTimeStamps), 'Wrong input.')
                               EntireMovieFieldNames =       fieldnames(Value.EntireMovie);
                               if isequal(obj.ExpectedFieldNames, EntireMovieFieldNames)
                                    type = 'Pooled';
                                elseif isequal(obj.ExpectedFieldNamesTwo, EntireMovieFieldNames)
                                    type = 'PooledTwo';
                               end

                       end

                 otherwise
                     error('Wrong input.')

            end


        end
         
        function compareFieldNames(~, one, two)
             
             if length(one) ~= length(two)
                fprintf('Different number of elements.\n') 
             else
                 for index = 1:length(one)
                    
                     if isequal(one{index}, two{index})
                        fprintf('%i: %s equals %s.\n', index, one{index}, two{index})  
                     else
                         fprintf('%i: %s does not equal %s.\n', index, one{index}, two{index})  
                     end
                     
                     
                 end
             end
             
         end
        
        function result =       convertPooledToIndividualMetaMata(~,Value)
            result.EntireMovie =            Value.EntireMovie;
            result.TimeStamp =              Value.PooledTimeStamps;
            result.RelativeTimeStamp =      Value.RelativeTimeStamps;
        end
  
    end
    
    methods (Access = private) % CURRENTLY NOT IN USE:
       
         function MergedMetaData =                   getMergedMetaData(obj)
                % this is worng here: should be moved to soemthing like: MetaDataSeries;
                MetaDataCell =                 obj.MetaDataOfSeparateMovies;
                
                NumberOfRows =                  unique(cellfun(@(x) x.EntireMovie.NumberOfRows, MetaDataCell));
                NumberOfColumns =               unique(cellfun(@(x) x.EntireMovie.NumberOfColumns, MetaDataCell));
                NumberOfPlanes =                unique(cellfun(@(x) x.EntireMovie.NumberOfPlanes, MetaDataCell));
                NumberOfChannels =              unique(cellfun(@(x) x.EntireMovie.NumberOfChannels, MetaDataCell));
                VoxelSizeX =                    unique(cellfun(@(x) x.EntireMovie.VoxelSizeX, MetaDataCell));
                VoxelSizeY =                    unique(cellfun(@(x) x.EntireMovie.VoxelSizeY, MetaDataCell));
                VoxelSizeZ =                    unique(cellfun(@(x) x.EntireMovie.VoxelSizeZ, MetaDataCell));

                assert(length(NumberOfRows) == 1 && length(NumberOfColumns) == 1 && length(NumberOfPlanes) == 1 && length(NumberOfChannels) == 1 && length(VoxelSizeX) == 1 && length(VoxelSizeY) == 1 && length(VoxelSizeZ) == 1, ...
                'Cannot combine the different files. Reason: Dimension or resolutions do not match')

                MergedMetaData.EntireMovie.NumberOfRows =                       NumberOfRows;
                MergedMetaData.EntireMovie.NumberOfColumns=                     NumberOfColumns;
                MergedMetaData.EntireMovie.NumberOfPlanes =                     NumberOfPlanes;

                MergedMetaData.EntireMovie.NumberOfChannels =                   NumberOfChannels;

                MergedMetaData.EntireMovie.VoxelSizeX=                          VoxelSizeX;
                MergedMetaData.EntireMovie.VoxelSizeY=                          VoxelSizeY;
                MergedMetaData.EntireMovie.VoxelSizeZ=                          VoxelSizeZ;

                MyListWithTimeStamps =                                          cellfun(@(x) x.TimeStamp, MetaDataCell, 'UniformOutput', false);

                MergedMetaData.PooledTimeStamps =                               unique(vertcat(MyListWithTimeStamps{:}));
                MergedMetaData.RelativeTimeStamps =                             MergedMetaData.PooledTimeStamps - MergedMetaData.PooledTimeStamps(1);  

                MergedMetaData.EntireMovie.NumberOfTimePoints  =                length(MergedMetaData.PooledTimeStamps);
                                
              
         end
            
    end
    
  
    
end