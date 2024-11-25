classdef DiscreteEnergyEnv4 < rl.env.MATLABEnvironment
    % DISCRETEENERGYENV: Create Energy Scheduling environment for reinforcement learning
    
    properties
        % 환경 변수 설정
        ConsumptionData
        SolarData
        TestConsumptionData
        TestSolarData
        ActionSpace = 5
        StepCount = 0
        PartialConsump = 0
        CurrentIndex = 2
        RecentConsump
        State
        StepsBeyondDone = []
        High = [300, 300, 300, 300]
        IsTestMode = false
    end
    
    methods
        function this = DiscreteEnergyEnv4()

            
            % 상태와 액션 공간 설정
            ObservationInfo = rlNumericSpec([3 1]);
            ObservationInfo.Name = 'Energy States';
            ObservationInfo.Description = 'PartialSum, PhotoVoltaic, LastTotal';
            
            ActionInfo = rlFiniteSetSpec([0 1 2 3 4]);
            ActionInfo.Name = 'Energy Action';
            
            % 부모 클래스 생성자 호출
            this = this@rl.env.MATLABEnvironment(ObservationInfo, ActionInfo);
            
            % 환경 초기화
            this.CurrentIndex = 2;
            
            % 훈련용 Excel 파일 읽기
            this.ConsumptionData = readmatrix('EnergyComsumptionData.xlsx', 'Range', 'A:A');
            this.SolarData = readmatrix('PhotovoltaicData.xlsx', 'Range', 'D:D');
                        
            % 환경 초기 상태 설정
            this.State = this.reset();
        end
        
        
        function [Observation, Reward, IsDone, LoggedSignals] = step(this, Action)
            LoggedSignals = [];
            assert(ismember(Action, 0:this.ActionSpace-1), 'Invalid action');
            
            % 상태 업데이트
            this.StepCount = this.StepCount + 1;
            partialSum = this.State(1);
            photoVoltaic = this.State(2);
            lastTotal = this.State(3);
            
            if Action == 0
                appAdd = 0;
            elseif Action == 1
                appAdd = 60;
            elseif Action == 2
                appAdd = 125;
            elseif Action == 3
                appAdd = 180;
            elseif Action == 4
                appAdd = 250;
            end
            
            total = partialSum + appAdd;
            
            % 보상 계산
            if photoVoltaic <= partialSum
                this.RecentConsump(end+1) = total;
                this.PartialConsump = this.PartialConsump + partialSum;
            end

            coeff1 = photoVoltaic/(photoVoltaic+partialSum);
            coeff2 = 1-coeff1;
    
            diff1 = -abs(photoVoltaic-total);
            diff2 = -abs(lastTotal - total)/100;
    
            Reward = coeff1*diff1 + coeff2*diff2 ;           
            
            fprintf('%f\t\t\t%f\t\t\t%f\t\t\t%f\n', photoVoltaic, partialSum, appAdd, Reward);

            % 다음 상태 계산
            partialSum = this.ConsumptionData(this.CurrentIndex);
            photoVoltaic = this.SolarData(this.CurrentIndex);
            
            this.CurrentIndex = this.CurrentIndex + 1;
            this.State = [partialSum; photoVoltaic; total];
            
            % 종료 조건 확인
            if this.StepCount == 24
                Reward = Reward - (sum(this.RecentConsump) - this.PartialConsump) / numel(this.RecentConsump);
                fprintf('penalty: %f\n', Reward);
                IsDone = true;
            else
                IsDone = false;
            end
            
            Observation = this.State;
        end
        
        function InitialObservation = reset(this)
            this.StepCount = 0;
            this.PartialConsump = 0;
            this.RecentConsump = [];
            
            if this.CurrentIndex == 2
                partialSum = this.ConsumptionData(this.CurrentIndex);
                photoVoltaic = this.SolarData(this.CurrentIndex);

                
                this.State = [partialSum; photoVoltaic; 150];
                this.CurrentIndex = this.CurrentIndex + 1;
            end 
            
            InitialObservation = this.State;
            
            fprintf('\n태양열\t\t\t가전제품\t\t\taction\t\t\t보상\n');
        end
    end
end
