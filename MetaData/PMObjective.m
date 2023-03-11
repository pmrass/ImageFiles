classdef PMObjective
    %PMOBJECTIVE For retrieving formatted description of objective
    
    properties (Access = private)
        Name
        Identifier
        NumericalAperture
        Magnification
        WorkingDistance
        PupilGeometry
        ImmersionRefractiveIndex
        Immersion

    end
    
    methods
        
        function obj = PMObjective(varargin)
            %PMOBJECTIVE Construct an instance of this class
            %   Takes 8 arguments:
            % 1: name
            % 2: identifier
            % 3: numerical aperture
            % 4: magnification
            % 5: working-distance
            % 6: pupil-geometry
            % 7: refractive index
            % 8: immersion
            
            NumberOfArguments = length(varargin);
            switch NumberOfArguments
                case 8
                    obj.Name =                          varargin{1};
                    obj.Identifier =                    varargin{2};
                    obj.NumericalAperture =             str2double(varargin{3});
                    obj.Magnification =                 str2double(varargin{4});
                    obj.WorkingDistance =               str2double(varargin{5});
                    obj.PupilGeometry =                 varargin{6};
                    obj.ImmersionRefractiveIndex =      str2double(varargin{7});
                    obj.Immersion =                     varargin{8};
                otherwise
                    error('Wrong input.')
            end
           
        end
        
        function summary = getSummary(obj)
            %GETSUMMARY return cell-string array with summary text;
            summary{1, 1}= sprintf('Name: %s', obj.Name);
            summary{2, 1}= sprintf('Identifier: %s', obj.Identifier);
            summary{3, 1}= sprintf('NumericalAperture: %4.3f', obj.NumericalAperture);
            summary{4, 1}= sprintf('Magnification: %i x', round(obj.Magnification));
            summary{5, 1}= sprintf('WorkingDistance: %i µm', round(obj.WorkingDistance));
            summary{6, 1}= sprintf('PupilGeometry: %s', obj.PupilGeometry);
            summary{7, 1}= sprintf('ImmersionRefractiveIndex: %6.5f', obj.ImmersionRefractiveIndex);
            summary{8, 1}= sprintf('Immersion: %s', obj.Immersion);
            
            
            
        end
    end
end

