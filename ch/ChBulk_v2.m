classdef ChBulk_v2
	%CHBULK_V2 Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		Area;
		Mode;
		Buildings;
		Draw;
		Region;
		WconfigLayout; % Used for WINNER: Layout of winner model
		WconfigParset; % Used for WINNER: Model parameters
		numRx; % Used for WINNER: Number of receivers, per model
		h; % Used for WINNER: Stored impulse response
	end
	
	methods(Static)
		
		
		function distance = getDistance(txPos,rxPos)
			distance = norm(rxPos-txPos);
		end
		
		function thermalNoise = ThermalNoise(NDLRB)
			switch NDLRB
				case 6
					BW = 1.4e6;
				case 15
					BW = 3e6;
				case 25
					BW = 5e6;
				case 50
					BW = 10e6;
				case 75
					BW = 15e6;
				case 100
					BW = 20e6;
			end
			
			T = 290;
			k = physconst('Boltzmann');
			thermalNoise = k*T*BW;
		end
		
		
		
		
	end
	
	methods(Access = private)
		
		function [numPoints,distVec,elavationProfile] = getElevation(obj,txPos,rxPos)
			
			elavationProfile(1) = 0;
			distVec(1) = 0;
			% Walk towards rxPos
			signX = sign(rxPos(1)-txPos(1));
			signY = sign(rxPos(2)-txPos(2));
			avgG = (txPos(1)-rxPos(1))/(txPos(2)-rxPos(2));
			position(1:2,1) = txPos(1:2);
			%plot(position(1,1),position(2,1),'r<')
			i = 2;
			numPoints = 0;
			while true
				% Check current distance
				distance = norm(position(1:2,i-1)'-rxPos(1:2));
				
				% Move position
				[moved_dist,position(1:2,i)] = move(position(1:2,i-1),signX,signY,avgG,0.1);
				distVec(i) = distVec(i-1)+moved_dist;
				%plot(position(1,i),position(2,i),'bo')
				% Check if new position is at a greater distance, if so, we
				% passed it.
				distance_n = norm(position(1:2,i)'-rxPos(1:2));
				if distance_n > distance
					break;
				else
					% Check if we're inside a building
					fbuildings_x = obj.Buildings(obj.Buildings(:,1) < position(1,i) & obj.Buildings(:,3) > position(1,i),:);
					fbuildings_y = fbuildings_x(fbuildings_x(:,2) < position(2,i) & fbuildings_x(:,4) > position(2,i),:);
					
					if ~isempty(fbuildings_y)
						elavationProfile(i) = fbuildings_y(5);
						if elavationProfile(i-1) == 0
							numPoints = numPoints +1;
						end
					else
						elavationProfile(i) = 0;
						
					end
				end
				i = i+1;
			end
			
			%figure
			%plot(elavationProfile)
			
			
			function [distance,position] = move(position,signX,signY,avgG,moveS)
				if abs(avgG) > 1
					moveX = abs(avgG)*signX*moveS;
					moveY = 1*signY*moveS;
					position(1) = position(1)+moveX;
					position(2) = position(2)+moveY;
					
				else
					moveX = 1*signX*moveS;
					moveY = (1/abs(avgG))*signY*moveS;
					position(1) = position(1)+moveX;
					position(2) = position(2)+moveY;
				end
				distance = sqrt(moveX^2+moveY^2);
			end
			
		end
		
		function [rxSig, SNRLin, rxPw] = addPathlossAwgn(obj,Station,User,txSig,varargin)
			thermalNoise = obj.ThermalNoise(Station.NDLRB);
			hbPos = Station.Position;
			hmPos = User.Position;
			distance = obj.getDistance(hbPos,hmPos)/1e3;
			switch obj.Mode
				case 'eHATA'
					[lossdB, ~] = ExtendedHata_MedianBasicPropLoss(Station.DlFreq, ...
						distance, hbPos(3), hmPos(3), obj.Region);
					
					% 					[numPoints,distVec,elev_profile] = obj.getElevation(hbPos,hmPos);
					%
					% 					if numPoints == 0
					% 						numPoints_scale = 1;
					% 					else
					% 						numPoints_scale = numPoints;
					% 					end
					%
					% 					elev = [numPoints_scale; distVec(end)/(numPoints_scale); hbPos(3); elev_profile'; hmPos(3)];
					%
					% 					lossdB = ExtendedHata_PropLoss(Station.DlFreq, hbPos(3), ...
					% 						hmPos(3), obj.Region, elev);
					
				case 'winner'
					
					if nargin > 3
						nVargs = length(varargin);
						for k = 1:nVargs
							if strcmp(varargin{k},'loss')
								lossdB = varargin{k+1};
							end
						end
					end
					
					
					
					
			end
			
			
			txPw = 10*log10(Station.Pmax)+30; %dBm.
			
			rxPw = txPw-lossdB;
			% SNR = P_rx_db - P_noise_db
			rxNoiseFloor = 10*log10(thermalNoise)+User.NoiseFigure;
			SNR = rxPw-rxNoiseFloor;
			SNRLin = 10^(SNR/10);
			str1 = sprintf('Station(%i) to User(%i)\n Distance: %s\n SNR:  %s\n',...
				Station.NCellID,User.UeId,num2str(distance),num2str(SNR));
			sonohilog(str1,'NFO0');
			
			%% Apply SNR
			
			% Compute average symbol energy
			% This is based on the number of useed subcarriers.
			% Scale it by the number of used RE since the power is
			% equally distributed
			Es = sqrt(2.0*Station.CellRefP*double(Station.WaveformInfo.Nfft)*Station.WaveformInfo.OfdmEnergyScale);
			
			% Compute spectral noise density NO
			N0 = 1/(Es*SNRLin);
			
			% Add AWGN
			
			noise = N0*complex(randn(size(txSig)), ...
				randn(size(txSig)));
			
			rxSig = txSig + noise;
			
		end
		
		function combinedLoss = getInterference(obj,Stations,station,user)
			
			% Get power of each station that is not the serving station and
			% compute loss based on pathloss or in the case of winner on
			% both.
			% Computation needs to be done per spectral component, thus
			% interference needs to be computed as a transferfunction
			% This means the non-normalized spectrums needs to be added
			% after pathloss is added.
			
			% v1 Uses eHATA based pathloss computation for both cases
			
			for iStation = 1:length(Stations)
				
				if Stations(iStation).NCellID ~= station.NCellID
					% Get rx of all other stations
					txSig = obj.addFading([...
						Stations(iStation).TxWaveform;zeros(25,1)],Stations(iStation).WaveformInfo);
					[rxSigNorm,~,rxPw(iStation)] = obj.addPathlossAwgn(Stations(iStation),user,txSig);
					
					% Set correct power of all signals, rxSigNorm is the signal
					% normalized. rxPw contains the estimated rx power based
					% on tx power and the link budget
					lossdB = 10*log10(bandpower(rxSigNorm))-rxPw(iStation);
					rxSig(:,iStation) =  rxSigNorm.*10^(-lossdB/20);
					
					
					
					rxPwP = 10*log10(bandpower(rxSig(:,iStation)));
				end
				
				
			end
			
			
			% Compute combined recieved spectrum (e.g. sum of all recieved
			% signals)
			
			intSig = sum(rxSig,2);
			
			% Get power of signal at independent frequency components.
			
			intSigLoss = 10*log10(bandpower(intSig));
			
			figure
			plot(10*log10(abs(fftshift(fft(intSig)).^2)));
			
			
			combinedLoss = 0;
			
		end
		
		function rx = addFading(obj,tx,info,varargin)
			
			
			
			switch obj.Mode
				case 'eHATA'
					cfg.SamplingRate = info.SamplingRate;
					cfg.Seed = 1;                  % Random channel seed
					cfg.NRxAnts = 1;               % 1 receive antenna
					cfg.DelayProfile = 'EPA';      % EVA delay spread
					cfg.DopplerFreq = 120;         % 120Hz Doppler frequency
					cfg.MIMOCorrelation = 'Low';   % Low (no) MIMO correlation
					cfg.InitTime = 0;              % Initialize at time zero
					cfg.NTerms = 16;               % Oscillators used in fading model
					cfg.ModelType = 'GMEDS';       % Rayleigh fading model type
					cfg.InitPhase = 'Random';      % Random initial phases
					cfg.NormalizePathGains = 'On'; % Normalize delay profile power
					cfg.NormalizeTxAnts = 'On';    % Normalize for transmit antennas
					% Pass data through the fading channel model
					rx = lteFadingChannel(cfg,tx);
				case 'winner'
					h = varargin{1};
					H = fft(h,length(tx));
					% Apply transfer function to signal
					X = fft(tx)./length(tx);
					Y = X.*H;
					rx = ifft(Y)*length(tx);
					
			end
			
		end
		
		function [cfgLayout,cfgModel] = initializeWinner(obj,Stations,Users)
			sonohilog('Initializing WINNER II channel model...','NFO')
			
			% Find number of base station types
			% A model is created for each type
			classes = unique({Stations.BsClass});
			for class = 1:length(classes)
				varname = classes{class};
				types.(varname) = find(strcmp({Stations.BsClass},varname));
				
			end
			
			Snames = fieldnames(types);
			
			cfgLayout = cell(numel(Snames),1);
			cfgModel = cell(numel(Snames),1);
			
			for model = 1:numel(Snames)
				type = Snames{model};
				stations = types.(Snames{model});
				
				% Get number of links associated with the station.
				users = nonzeros([Stations(stations).Users]);
				numLinks = nnz(users);
				
				if isempty(users)
					% If no users are associated, skip the model
					continue
				end
				[AA, eNBIdx, userIdx] = sonohiWINNER.configureAA(type,stations,users);
				
				range = max(obj.Area);
				
				cfgLayout{model} = sonohiWINNER.initializeLayout(userIdx, eNBIdx, numLinks, AA, range);
				
				cfgLayout{model} = sonohiWINNER.addAssociated(cfgLayout{model},stations,users);
				
				cfgLayout{model} = sonohiWINNER.setPositions(cfgLayout{model},Stations,Users);
				
				
				cfgLayout{model}.Pairing = obj.getPairing(Stations(cfgLayout{model}.StationIdx));
				
				cfgLayout{model} = sonohiWINNER.updateIndexing(cfgLayout{model},Stations);
				
				cfgLayout{model} = sonohiWINNER.setPropagationScenario(cfgLayout{model},Stations,Users, obj);
				
				cfgModel{model} = sonohiWINNER.configureModel(cfgLayout{model},Stations);
				
			end
			
		end
		
		function [obj] = configureWinner(obj)
			% Computes impulse response of initalized winner model
			for model = 1:length(obj.WconfigLayout)
				wimCh = comm.WINNER2Channel(obj.WconfigParset{model}, obj.WconfigLayout{model});
				chanInfo = info(wimCh);
				numTx    = chanInfo.NumBSElements(1);
				Rs       = chanInfo.SampleRate(1);
				obj.numRx{model} = chanInfo.NumLinks(1);
				impulseR = [ones(1, numTx); zeros(obj.WconfigParset{model}.NumTimeSamples-1, numTx)];
				h{model} = wimCh(impulseR);
			end
			obj.h = h;
			
		end
		
		
	end
	
	methods
		function obj = ChBulk_v2(Param)
			obj.Area = Param.area;
			obj.Mode = Param.channel.mode;
			obj.Buildings = Param.buildings;
			obj.Draw = Param.draw;
			obj.Region = Param.channel.region;
		end
		
		
		
		function [Stations,Users,obj] = traverse(obj,Stations,Users)
			
			
			% Assuming one antenna port, number of links are equal to
			% number of users scheuled in the given round
			users  = [Stations.Users];
			numLinks = nnz(users);
			
			Pairing = obj.getPairing(Stations);
			% Apply channel based on configuration.
			if strcmp(obj.Mode,'winner')
				
				%Check if transfer function is already computed:
				% If empty, e.g. not computed, compute impulse response and
				% store it for next syncroutine.
				if isempty(obj.h)
					[obj.WconfigLayout, obj.WconfigParset] = obj.initializeWinner(Stations,Users);
					obj = obj.configureWinner();
				else
					sonohilog('Using previously computed transfer function','NFO0')
				end
				
				
				
				% Compute Rx for each model
				for model = 1:length(obj.WconfigLayout)
					
					if isempty(obj.WconfigLayout{model})
						sonohilog(sprintf('Nothing assigned to %i model',model),'NFO')
						continue
					end
					
					
					
					% Debugging code. Use of direct waveform for validating
					% transferfunction
					%release(wimCh)
					%rxSig2 = wimCh(Stations(obj.WconfigLayout{model}.StationIdx(1)).TxWaveform);
					
					% Go through all links for the given scenario
					% 1. Compute transfer function for each link
					% 2. Apply transferfunction and  compute loss
					% 3. Add loss as AWGN
					for link = 1:obj.numRx{model}
						% Get TX from the WINNER layout idx
						txIdx = obj.WconfigLayout{model}.Pairing(1,link);
						% Get RX from the WINNER layout idx
						rxIdx = obj.WconfigLayout{model}.Pairing(2,link)-length(obj.WconfigLayout{model}.StationIdx);
						Station = Stations(obj.WconfigLayout{model}.StationIdx(txIdx));
						User = Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx));
						% Get corresponding TxSig
						txSig = [Station.TxWaveform;zeros(25,1)];
						txPw = 10*log10(bandpower(txSig));
						
						%figure
						%plot(10*log10(abs(fftshift(fft(txSig)).^2)))
						%hold on
						
						rxSig = obj.addFading(txSig,[],obj.h{model}{link});
						
						rxPw_ = 10*log10(bandpower(rxSig));
						
						lossdB = txPw-rxPw_;
						%plot(10*log10(abs(fftshift(fft(rxSig)).^2)));
						%plot(10*log10(abs(fftshift(fft(rxSig2{1}))).^2));
						
						% Normalize signal and add loss as AWGN based on
						% noise floor
						rxSigNorm = rxSig.*10^(lossdB/20);
						[rxSigNorm, SNRLin, rxPw] = obj.addPathlossAwgn(Station, User, rxSigNorm, 'loss', lossdB);
						
						%plot(10*log10(abs(fftshift(fft(rxSigNorm)).^2)),'Color',[0.5,0.5,0.5,0.2]);
						
						% Assign to user
						Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxInfo.SNRdB = 10*log10(SNRLin);
						Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxInfo.SNR = SNRLin;
						Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxInfo.rxPw = rxPw;
						Users([Users.UeId] == obj.WconfigLayout{model}.UserIdx(rxIdx)).RxWaveform = rxSigNorm;
						
					end
					
				end
				
				
			elseif strcmp(obj.Mode,'eHATA')
				for i = 1:numLinks
					station = Stations(Pairing(1,i));
					Users(Pairing(2,i)).RxWaveform = obj.addFading([...
						station.TxWaveform;zeros(25,1)],station.WaveformInfo);
					
					%interLossdB = obj.getInterference(Stations,station,Users(Pairing(2,i)));
					
					[Users(Pairing(2,i)).RxWaveform, SNRLin, rxPw] = obj.addPathlossAwgn(...
						station,Users(Pairing(2,i)),Users(Pairing(2,i)).RxWaveform);
					
					
					
					Users(Pairing(2,i)).RxInfo.SNRdB = 10*log10(SNRLin);
					Users(Pairing(2,i)).RxInfo.SNR = SNRLin;
					Users(Pairing(2,i)).RxInfo.rxPw = rxPw;
					
				end
			end
			
		end
		
		function Pairing = getPairing(obj,Stations)
			users  = [Stations.Users];
			
			nlink=1;
			for i = 1:length(Stations)
				for ii = 1:nnz(users(:,i))
					Pairing(:,nlink) = [i; users(ii,i)];
					nlink = nlink+1;
				end
			end
			
		end
		
		function pwr = calculateReceivedPower(obj, User, Station)
			% calculate pathloss and fading for this link
			rxWaveform = obj.addFading([Station.TxWaveform;zeros(25,1)], ...
				Station.WaveformInfo);
			rxWaveform = obj.addPathlossAwgn(Station, User, rxWaveform);
			
			pwr = bandpower(rxWaveform);
		end
		
		function [snr, evm] = calculateSignalDegradation(obj, User, Station)
			% calculate pathloss and fading for this link
			rxWaveform = obj.addFading([Station.TxWaveform;zeros(25,1)], ...
				Station.WaveformInfo);
			[rxWaveform, snr] = obj.addPathlossAwgn(Station, User, rxWaveform);
			
			% TODO remove stub for EVM
			evm = 0;
		end
		
		
		function obj = resetWinner(obj)
			obj.h = [];
			obj.numRx = [];
			obj.WconfigLayout = [];
			obj.WconfigParset = [];
		end
		
	end
end
