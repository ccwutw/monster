function Mimo = generateMimoConfig(Config, varargin)
% Generates a MIMO configuration structure from Config parameters
%
% :param Config: MonsterConfig instance
% :param varargin: string optional to specify the type of node one of macro|micro|ue
% :return Mimo: struct with Mimo configuration
% 
	if ~isempty(varargin) && strcmp(varargin{1}, 'micro')
		Mimo = struct(...
			'arrayTuple', [1, 1, 1, 1, 1], ...
			'txMode', 'Port0',...
			'numAntennas', 1 ...
			);
	else
		Mg = 1; % number of panels along X
		Ng = 1; % nuber of panels along Y
		M = Config.Mimo.elementsPerPanel(1); % number of elements per panel along X
		N = Config.Mimo.elementsPerPanel(2); % number of elements per panel along Y
		P = 1; % polarization

		Mimo = struct(...
			'arrayTuple', [Mg, Ng, M, N, P], ...
			'txMode', Config.Mimo.transmissionMode,...
			'numAntennas', Mg*Ng*M*N ...
			);
	end	
end