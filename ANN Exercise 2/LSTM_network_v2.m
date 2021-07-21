% Load the sequence data
load lasertrain.dat
load laserpred.dat

% Partition the training and test data. Train on the first 90% of the sequence and test on the last 10%.

numTimeStepsTrain = floor(numel(lasertrain));

dataTrain = lasertrain';
dataTest = laserpred';

data = [dataTrain dataTest];

% Standardize data
mu = mean(dataTrain);
sig = std(dataTrain);

dataTrainStandardized = (dataTrain - mu) / sig;

% Prepare Predictors and Responses this is example of lag = 1

% XTrain = dataTrainStandardized(1:end-1);
% YTrain = dataTrainStandardized(2:end);

% numbr of lags
p = 1;

[XTrain,YTrain]=getTimeSeriesTrainData(dataTrainStandardized', p);


% Define LSTM Network Architecture
% Create an LSTM regression network. Specify the LSTM layer to have 200 hidden units.

numFeatures = p;
numResponses = 1;
numHiddenUnits = 200;

layers = [ ...
    sequenceInputLayer(numFeatures)
    lstmLayer(numHiddenUnits)
    fullyConnectedLayer(numResponses)
    regressionLayer];
% Specify the training options. Set the solver to 'adam' and train for 250 epochs. 
% To prevent the gradients from exploding, set the gradient threshold to 
% 1. Specify the initial learn rate 0.005, and drop the learn rate after 125 epochs by multiplying by a factor of 0.2.

options = trainingOptions('adam', ...
    'MaxEpochs',250, ...
    'GradientThreshold',1, ...
    'InitialLearnRate',0.005, ...
    'LearnRateSchedule','piecewise', ...
    'LearnRateDropPeriod',125, ...
    'LearnRateDropFactor',0.2, ...
    'Verbose',0, ...
    'Plots','training-progress');

% Train LSTM Network

net = trainNetwork(XTrain,YTrain,layers,options);

% Forecast Future Time Steps
% To forecast the values of multiple time steps in the future, use the predictAndUpdateState function 
% to predict time steps one at a time and update the network state at each prediction.
% For each prediction, use the previous prediction as input to the function.

% Standardize the test data using the same parameters as the training data.

dataTestStandardized = (dataTest - mu) / sig;

[XTest,YTest]=getTimeSeriesTrainData(dataTestStandardized', p);
% XTest = dataTestStandardized(1:end-1);

% To initialize the network state, 
% first predict on the training data XTrain. 
% Next, make the first prediction using the last time step of the training response YTrain(end). 
% Loop over the remaining predictions and input the previous prediction to predictAndUpdateState.

net = predictAndUpdateState(net,XTrain);
[net,YPred] = predictAndUpdateState(net,YTrain(end));

numTimeStepsTest = numel(XTest);
for i = 2:numTimeStepsTest
    [net,YPred(:,i)] = predictAndUpdateState(net,YPred(:,i-1),'ExecutionEnvironment','cpu');
end

% Unstandardize the predictions using the parameters calculated earlier.
YPred = sig*YPred + mu;

% The training progress plot reports the root-mean-square error (RMSE) calculated from the standardized data. 
% Calculate the RMSE from the unstandardized predictions.
% YTest = dataTest(2:end);
rmse = sqrt(mean((YPred-YTest).^2))

% Plot the training time series with the forecasted values.
figure
plot(dataTrain(1:end-1))
hold on
idx = numTimeStepsTrain:(numTimeStepsTrain+numTimeStepsTest);
plot(idx,[data(numTimeStepsTrain) YPred],'.-')
hold off
xlabel("Month")
ylabel("Cases")
title("Forecast")
legend(["Observed" "Forecast"])

% Compare the forecasted values with the test data.
figure
subplot(2,1,1)
plot(YTest)
hold on
plot(YPred,'.-')
hold off
legend(["Observed" "Forecast"])
ylabel("Cases")
title("Forecast")

subplot(2,1,2)
stem(YPred - YTest)
xlabel("Month")
ylabel("Error")
title("RMSE = " + rmse)

% Update Network State with Observed Values

% If you have access to the actual values of time steps between predictions, 
% then you can update the network state with the observed values instead of the predicted values.
% 
% First, initialize the network state. To make predictions on a new sequence, reset the network state using resetState. 
% Resetting the network state prevents previous predictions from affecting the predictions on the new data.
% Reset the network state, and then initialize the network state by predicting on the training data.
net = resetState(net);
net = predictAndUpdateState(net,XTrain);

% Predict on each time step. For each prediction, predict the next time step using the observed value of the previous time step.
% Set the 'ExecutionEnvironment' option of predictAndUpdateState to 'cpu'.
YPred = [];
numTimeStepsTest = numel(XTest);
for i = 1:numTimeStepsTest
    [net,YPred(:,i)] = predictAndUpdateState(net,XTest(:,i),'ExecutionEnvironment','cpu');
end

% Unstandardize the predictions using the parameters calculated earlier.
YPred = sig*YPred + mu;
% Calculate the root-mean-square error (RMSE).
rmse = sqrt(mean((YPred-YTest).^2))

% Compare the forecasted values with the test data.

figure
subplot(2,1,1)
plot(YTest)
hold on
plot(YPred,'.-')
hold off
legend(["Observed" "Predicted"])
ylabel("Cases")
title("Forecast with Updates")

subplot(2,1,2)
stem(YPred - YTest)
xlabel("Month")
ylabel("Error")
title("RMSE = " + rmse)

% Here, the predictions are more accurate when updating the network state with the observed values instead of the predicted values.

