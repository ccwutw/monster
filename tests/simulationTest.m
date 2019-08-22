classdef simulationTest < matlab.unittest.TestCase
    %Test for simulation
    properties 
        Config;
        Simulation;
    end
    methods (TestClassSetup)
        function createObjects(testCase)
            testCase.Config = MonsterConfig();

            testCase.Simulation = Monster(testCase.Config);
        end
    end


    methods (Test)
        function testConstructor(testCase)
            testCase.verifyTrue(isa(testCase.Simulation, 'Monster'));
        end

        function testSetupRound(testCase)
            %Setup simulation for round 0
            iRound = 0;
            testCase.Simulation.setupRound(iRound);
            testCase.verifyTrue(testCase.Config.Runtime.currentRound == iRound);
            testCase.verifyTrue(testCase.Config.Runtime.currentTime == iRound*10e-3);
            testCase.verifyTrue(testCase.Config.Runtime.remainingTime == (testCase.Config.Runtime.totalRounds - testCase.Config.Runtime.currentRound)*10e-3);
            testCase.verifyTrue(testCase.Config.Runtime.remainingRounds == testCase.Config.Runtime.totalRounds - testCase.Config.Runtime.currentRound - 1);

            %Test for channel setup as well???
            
            

        end

        function testRun(testCase)
            
            %Run the simulation loop
            testCase.Simulation.run();
            
        end

        function testCollectResults(testCase)
            testCase.Simulation.collectResults();

        end

        function testClean(testCase)
            testCase.Simulation.clean();
            %Test that stations and users are reset
            %Test Stations
            arrayfun(@(x) testCase.verifyEqual(x.NSubframe, mod(1,10)) , testCase.Simulation.Stations);

            for iStation = 1:testCase.Config.MacroEnb.number + testCase.Config.MicroEnb.number
                clear temp;
                temp(1:testCase.Simulation.Stations(iStation).NDLRB,1) = struct('UeId', -1, 'Mcs', -1, 'ModOrd', -1, 'NDI', 1);
                testCase.verifyEqual(testCase.Simulation.Stations(iStation).ScheduleDL  , temp );
            end

            arrayfun(@(x) testCase.verifyEqual(x.Tx.Ref ,struct('ReGrid',[], 'Waveform',[], 'WaveformInfo',[],'PSSInd',[],'PSS', [],'SSS', [],'SSSInd',[],'PSSWaveform',[], 'SSSWaveform',[])), testCase.Simulation.Stations);
            arrayfun(@(x) testCase.verifyEqual(x.Tx.ReGrid , []), testCase.Simulation.Stations);
            arrayfun(@(x) testCase.verifyEqual(x.Tx.Waveform ,[]), testCase.Simulation.Stations);
            arrayfun(@(x) testCase.verifyEqual(x.Tx.WaveformInfo ,[]), testCase.Simulation.Stations);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.UeData, []), testCase.Simulation.Stations);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Waveform, []), testCase.Simulation.Stations);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.RxPwdBm, []), testCase.Simulation.Stations);

            %Test Ue
            arrayfun(@(x) testCase.verifyEqual(x.Scheduled, struct('DL', false, 'UL', false)), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Symbols, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.SymbolsInfo, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Codeword, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.CodewordInfo, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.TransportBlock, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.TransportBlockInfo, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Tx.Waveform, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Tx.ReGrid, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.NoiseEst, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.RSSIdBm, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.RSRQdB, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.RSRPdBm, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.SINR, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.SINRdB, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.SNR, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.SNRdB, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Waveform, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.RxPwdBm, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Subframe, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.EstChannelGrid, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.EqSubframe, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.TransportBlock, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Crc, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.PreEvm, 0 ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.PostEvm, 0 ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.BLER, 0 ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Throughput, 0 ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.SchIndexes, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.PDSCH, [] ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Blocks, struct('ok', 0, 'err', 0, 'tot', 0) ), testCase.Simulation.Users);
            arrayfun(@(x) testCase.verifyEqual(x.Rx.Bits, struct('ok', 0, 'err', 0, 'tot', 0) ), testCase.Simulation.Users);

        end
    end

end