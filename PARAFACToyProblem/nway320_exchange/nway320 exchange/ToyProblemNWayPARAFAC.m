%% Toy problem for testing Nway PCA on a simulated data set 
% FS Middleton 2022/05/04
%INDAFAC code sourced from:
% Giorgio Tomasi and Rasmus Bro
%PARAFAC and missing values
%Chemometrics and Intelligent Laboratory Systems 75(2004)163-180

%%
clc
clear
%% Import and export toy data arrays 
%dimensions of the toy array 
dim1 = 30;
dim2 = 40;
dim3 = 5;
dim4 = 4;

%[X,SeedOut,Factors{1:length(dimX)}] = CreaMiss(Rank,dimX,Noise,Congruence,Missing,Mode,SeedIn);
%create true data 
[Xtrue, Seed, Factors] = CreaMiss(4, [dim1,dim2,dim3,dim4], 0.01, 0, 0, 'RMV',42);


missing =90;
filename = ['ToyProblemData4D_',num2str(missing),'%missing.xlsx'];

export =1; %set to 0 to import 

if export ==1
    %create the matrix with missing entries 
    [X, Seed, Factors] = CreaMiss(4, [dim1,dim2,dim3, dim4], 0.01, 0, missing/100, 'RMV',42);
    %[X,Seed,varargout] = CreaMiss(Fac,DimX,Noise,Congruence,Missing,modeINDAFAC,SD)
    %export it 
    Tf = array2table(Factors);
    writetable(Tf,filename,'Sheet','Factors')

    for i = 1:dim3
        for j =1:dim4
        % create missing matrix
        T=array2table(reshape(X(:,:,i,j),dim1,dim2));
        sheetname = strcat(num2str(i),';',num2str(j));
        writetable(T, filename, 'Sheet', sheetname)
        end
    end 
else 
    %import 
    dim = [5,30,40];
    missing = 50;
    filename = ['ToyProblemData3D_',num2str(missing),'%missing.xlsx'];
    [X, Xtrue, Factors] = importX(filename, dim);  
end 

%% Tensor completion loops
% Tensor completion, allowing the global minimum for a number of factors
% and an array with a %missing from the true array 

% import data to initialise vars 
dim = [5,30,40];
missing = 90; % maximum amount missing -> smallest number of entries in filled_linear_ind and greatest of missing_ind
filename = ['ToyProblemData3D_',num2str(missing),'%missing.xlsx'];

[X, Xtrue, Factors] = importX(filename, dim);
missing_ind = find(isnan(X));
filled_linear_ind = find(~isnan(X));
% can also get Rho, Lambda, EV% and Max Gr
% EV must be close to 100%

%Find the correct number of factors 
missing = [10,20,30,40,50,60,70,80,90];
%  number of factors maximum to try 
N=10;


% for each % missing 
minmse = zeros(1,length(missing));
numberOfFactors = zeros(1,length(missing));
dof = zeros(1,length(missing));
mse = zeros(N,length(missing));
msefill = zeros(N,length(missing));
indexsortmse=zeros(N,length(missing));
c = zeros(N,length(missing));
coreconsistency = zeros(N,1);
randomstart = zeros(N,length(missing));

%metrics defined
smse = zeros(N,1);
fit = zeros(N,1);
it = zeros(N,1);
error = zeros(N, length(missing_ind));%missing_ind is biggest for 90% missing data, as initialisation was
errorfill = zeros(N,length(missing_ind));
% metrics to compare to truth 
msemiss = zeros(N,1);
errormiss = zeros(N, length(missing_ind));
% define other needed vars  
X_pred = zeros(dim(1),dim(2),dim(3),N);
center = 1;
scale = 1;
modeINDAFAC =1;
method = 'Broindafac';
alphabet = 'ABCD'; %will use maximum 4way data
randnum=linspace(1,100,50);
count = 0; % index for the missing data arrays
mse_threshold = 25;
% time the process 
tic 
for miss = missing
    disp('% missing')
    disp(miss)
    count = count+1;
    dim = [5,30,40];
    %import wanted data 
    filename = ['ToyProblemData3D_',num2str(miss),'%missing.xlsx'];
    [X, Xtrue, Factors] = importX(filename, dim);
    filled_linear_ind = find(~isnan(X));
    missing_ind = find(isnan(X));
    no_filled = miss/100*dim(1)*dim(2)*dim(3);
    %remove nan slabs from the 3-way array 
    [X,dim, znan, ynan, xnan]=remove_nan(X);
    % Find the correct number of factors for this percent missing 
    for n = 1:N % factors (== principal components) 
        % initialise random number generator 
        randind = 1;
        rng(randind, 'twister')
        
        disp('n')
        disp(n) 
        %perform INDAFAC with missing values on the matrix with one entry missing
        %[F,D, X_pred]=missing_indafac(X,fn,modeINDAFAC, center,scale,conv,max_iter)
        [F,D, X_pred]=missing_indafac(X,n,modeINDAFAC, center,scale,1e-3,1000,method);
        Xm = nmodel(F);
        errorfill(n,1:length(filled_linear_ind)) = (X(filled_linear_ind)-Xm(filled_linear_ind))'; % actual prediction error
        % averages of metrics 
        msefill(n,count) = sum(errorfill(n,1:length(filled_linear_ind)).^2)/length(filled_linear_ind);

        %if the correct starting value was not used, the error will be very
        %great 
        % can make this a for loop for future code 
        while msefill(n,count) > mse_threshold
            randind=randind+1;
            rng(randind,'twister')
            %refit 
            [F,D, X_pred]=missing_indafac(X,n,modeINDAFAC, center,scale,1e-3,1000,method);
            Xm = nmodel(F);
            errorfill(n,1:length(filled_linear_ind)) = (X(filled_linear_ind)-Xm(filled_linear_ind))'; % actual prediction error
            % averages of metrics 
            msefill(n,count) = sum(errorfill(n,1:length(filled_linear_ind)).^2)/length(filled_linear_ind);
        end 
        randomstart(n,count) = randind;
        %built in metric
        fit(n,count) = D.fit; 
        error(n,1:length(filled_linear_ind)) = (Xtrue(filled_linear_ind)-Xm(filled_linear_ind))';
        errormiss(n,1:length(missing_ind))= (Xtrue(missing_ind)-Xm(missing_ind))';
        msemiss(n,count) = sum(errormiss(n,1:length(missing_ind)).^2)/length(missing_ind);
        mse(n,count) = sum(error(n,1:length(filled_linear_ind)).^2)/length(filled_linear_ind);
        %[Consistency,G,stdG,Target]=corcond(X,Factors,Weights,Plot)
        c(n,count)= corcond(Xm,F,[],1);
    end
    % Find true number of factors for this % missing 
    %Find the optimal rank prediction
    [sortmse, indexsortmse(:,count)]=sort(mse(:,count)); % sorts in ascending order 
    m = 0; % counter for finding consisent number of factors with lowest mse 
    check =1;
    coreconsistency = c(:,count);
    while check==1
        m=m+1;
        if coreconsistency(indexsortmse(m,count))>0.9 % should be consistent 
            check =0;
        end 
    end 
    minmse(count) = sortmse(m);
    numberOfFactors(count) = indexsortmse(m,count);
    cmin = coreconsistency(numberOfFactors(count));
    dof(count) = dim(1)*dim(2)*dim(3)-numberOfFactors(count)*(dim(1)+dim(2)+dim(3)-2);
    % find the model 
    [F,D, X_pred(:,:,:,n)]=missing_indafac(X,numberOfFactors(count),modeINDAFAC, center,scale,1e-3,1000, method);
end
toc % end timer 


%% LOOCV for the correct number of factors for a % missing 
% must be run after the correct nnumber of factors is found 
missingLOOCV = 50;
dim = [5,30,40];
rng(2,'twister')
numberOfFactorsLOOCV =4;% = numberOfFactors(missing==missingLOOCV);
filename = ['ToyProblemData3D_',num2str(missingLOOCV),'%missing.xlsx'];
[X, Xtrue, Factors] = importX(filename, dim);
filled_linear_ind = find(~isnan(X));
missing_ind = find(isnan(X));
% find filled indices 
[i,j,k]=findfill3(X);
% define metrics here that need to be used 
N = length(filled_linear_ind);
smseN = zeros(1,N);
fitN = zeros(1,N);
itN = zeros(1,N);
errorN = zeros(1,N);
mseN = zeros(1,N);
cN = zeros(1,N);
coreconsistencyN = zeros(1,N);
% can also get Rho, Lambda, EV% and Max Gr
% EV must be close to 100%
% define how to use method again 
center = 1;
scale = 1;
modeINDAFAC =1;
method = 'Broindafac';

% define other needed vars 
X_predN = zeros(dim(1),dim(2),dim(3),N);
n = 1; % factors (== principal components) 
% LOOCV
count=0;% counter for LOOCV
ind = 0; % counter for filled indices 

% time the LOOCV
tic
for filled_ind = filled_linear_ind' %filled_linear_ind must be a row vector  
    % temporary X
    X_b = X;
    ind=ind+1;
    disp(ind)
    X_b(filled_ind) = nan;% remove a point from Xs
    if find(~isnan(X_b(i(ind),j(ind),:))) &  find(~isnan(X_b(i(ind),:,k(ind))))&  find(~isnan(X_b(i(ind),:,k(ind))))%ensure at least one value in each column and row
        count=count+1; % allowed, therefore the counter is increased 
        %perform INDAFAC with missing values on the matrix with one entry missing
        %[F,D, X_pred]=missing_indafac(X,fn,modeINDAFAC, center,scale,conv,max_iter)
        [F,D, X_pred(:,:,:,count)]=missing_indafac(X_b,numberOfFactorsLOOCV,modeINDAFAC, center,scale,1e-3,1000,method);
        Xm = nmodel(F);
        %built in metric
        fit(n,count) = D.fit;
        %own metrics 
        % fix this 
        errorN(n,count) = Xtrue(filled_ind)-Xm(filled_ind);
        while errorN(n,count) >1
            rand(erorrN(n,count),'twister') % new random values 
            [F,D, X_pred(:,:,:,count)]=missing_indafac(X_b,numberOfFactorsLOOCV,modeINDAFAC, center,scale,1e-3,1000,method);
            Xm = nmodel(F);
        end 
        %[Consistency,G,stdG,Target]=corcond(X,Factors,Weights,Plot)
        cN(n,count)= corcond(Xm,F,[],1);
    end 
end %end LOOCV 
% averages of metrics for LOOCV 
msebest = sum(errorN(n,:).^2)./length(errorN(n,:));
coreconsistencybest = sqrt(sum(cN(n,:).^2)./length(cN(n,:)));

toc 
%% confirm rank with plots 
% cor consistency must be close to 100%
xplot = 1:N;
subplot(3,1,1)
plot(xplot, c(xplot),  'k.','MarkerSize',15)
ylabel('Consistency')
% These will show sharp decline and stabilisation upon discovery of the
% true rank
subplot(3,1,2)
plot(xplot, smse(xplot), 'k.','MarkerSize',15)
ylabel('Square root of the mean squared Error')

subplot(3,1,3)
plot(xplot, fit(xplot),  'k.','MarkerSize',15)
xlabel('Components')
ylabel('Fit: Loss function ')
%% Plt the missing data structure 
% these must have the same sizes as x
v=X;

xslice = [15,25];    % location of y-z planes
yslice = [2,3,4,5];              % location of x-z plane
zslice = [1,25];         % location of x-y planes
clf
slice(v,xslice,yslice,zslice)
xlabel('x')
ylabel('y')
zlabel('z')
%% 
function [X,dim, znan, ynan, xnan]=remove_nan(X)
    % saves the columns and rows with only Nan values 

    % isnan(X) returns logical array 
    % all(isnan(X),1) is also a logical array (1x30x40) - each row
    % find(all(isnan(X),1)) returns linear indices -> reshape array to correct
    % dimension to find missing slabs 
    dim = size(X);
    % z slabs
    t1 = all(isnan(X),[1,2]);
    t1 = reshape(t1,[1,dim(3)]); %logical 
    r1=find(t1);
    X(:,:,r1)=[];

    % x slabs 
    t2 = all(isnan(X),[2,3]);
    t2 = reshape(t2,[1,dim(1)]); %logical 
    r2=find(t2);
    X(:,:,r2)=[];

    % y slabs 
    t3 = all(isnan(X),[1,3]);
    t3 = reshape(t3,[1,dim(2)]); %logical 
    r3=find(t3);
    X(:,:,r3)=[];

     %new X 
    dim = size(X);
    znan=r1;
    xnan=r2;
    ynan=r3;

end 

function [X, Xtrue, Factors] = importX(filename, dim)
    Factors = readtable(filename, 'Sheet', 'Factors');
    X=zeros(dim(1),dim(2),dim(3));
    Xtrue=zeros(dim(1),dim(2),dim(3));
    for i =1:dim(1)
        Ttrue = readtable('ToyProblemData3DFull.xlsx','Sheet', num2str(i));
        Xtrue(i,:,:)= table2array(Ttrue);
        T = readtable(filename, 'Sheet', num2str(i));
        X(i,:,:)=table2array(T);
    end
end

function [F,D, X_pred]=missing_indafac(X,fn,modeINDAFAC, center,scale,conv,max_iter,method)
% Input 
% X = data array 
% fn = number of factors 
% modeINDAFAC = mode of unfolding used 
% center  =1 center data 
% scale  =1 scale data 
%         =0 do not scale data  
% conv = convergence criterion = difference between new and old 
% method ='parafac' or 'indafac' or 'Broindafac'
 
% Output 
% F = factors (A,B,C)
% D = diagnostics 
%     D.it = iterations 
%     D.fit = fit
%     D.error = error
%     D.cor = core consistency 
%     D.stop = reason for stopping (max iterations or conv reached)
% X_pred = predicted array 

% INDAFAC is used to find the factors of a 3-way array for a given number
% of factors (fn), with options as to how to unfold the matrix for centering and scaling, 
% as well as whether to center and scale and when to stop iterations 


    dim=size(X);
    [i,j,k]=findnan3(X); % missing indices 
    if method == 'Broindafac'
        % use their indafac algorithm, not my method 
        Fi = ini(X, fn, 1); % initialise the three loadings 
        [F,D]=INDAFAC(X,fn,Fi, diagnostics='off');
        Xm = nmodel(F);
        X_pred = X;
        % fill misssing values 
        for d = 1:length(i)
            X_pred(i(d),j(d),k(d))= Xm(i(d),j(d),k(d));
        end
    else 
        % this only uses indafac to find the loadings, with my own
        % centering and updating 
        % much longer to run algorithm 
        if length(i)>1 % there is missing data 
            Xf = filldata3(X); % fill slices with averages  
            SS = sumsquare3(Xf,i,j,k); % sum of squares of missing values 
            X_pred = X;
            f=2*conv;
            iter = 1;
            while iter<max_iter && f>conv
                SSold = SS;
                % preprocess = scale and then center 

                if scale ==1 || center ==1
                    [x1,x2,x3]=nshape(Xf);
                    %unfold
                    if modeINDAFAC ==1
                        Xp=x1;
                    elseif modeINDAFAC ==2
                        Xp = x2;
                    else 
                        Xp = x3;
                    end
                    %scale 
                    if scale ==1 
                        sj = sqrt(sum(sum((Xp).^2)));
                        Xp = Xp/sj;
                    end 
                    % center
                    if center ==1
                        mx = mean(Xp);
                        % Center X across columns
                        Xp = Xp-mx*ones(size(mx,2),1);
                    end 
                    % reshapes back to 3-way array 
                    Xc=reshape(Xp,size(X));
                else
                    Xc = Xf;
                end 

                % Find factors 
                % initial guess for factors 

                Fi = ini(Xc, fn, 1); % initialise the three loadings
                alphabet = 'ABCD'; 

                for alph=1:3 %each loading for each dimension of the data
                    eval([alphabet(alph) ,'= Fi{alph};']);
                end 
                % indafac or parafac step 
                if strcmp(method,'indafac') 

                    [F,D]=INDAFAC(Xc,fn,Fi);
                    Xm = nmodel(F);
                else 
                    [F, ~]=parafac(Xc,fn);
                    Xm = nmodel(F);
                end 

                % post process = uncenter, unscale 
                if scale ==1 || center ==1
                    [x1,x2,x3]=nshape(Xm);
                    %unfold
                    if modeINDAFAC ==1
                        Xp=x1;
                    elseif modeINDAFAC ==2
                        Xp = x2;
                    else 
                        Xp = x3;
                    end
                    % uncenter
                    if center ==1
                        Xp = Xp+mx*ones(size(mx,2),1);
                    end 
                    % unscale 
                    if scale ==1 
                        Xp = Xp*sj;
                    end 
                    % reshapes back to 3-way array 
                    X_pred=reshape(Xp,size(X));
                else
                    X_pred = Xm;
                end  

                % fill misssing values 
                for d = 1:length(i)
                    Xf(i(d),j(d),k(d))= X_pred(i(d),j(d),k(d));
                end 
                % check for convergence 
                SS = sumsquare3(Xf,i,j,k); % sum of squares of missing values 
                f = abs(SS-SSold)/(SSold);
                iter = iter+1;
            end
            X_pred = Xf;
        else 
            % no missing data
            disp('No missing data')
        end %end if  else
    end
end % end function 

function [X_filled, missing] = filldata3(X)
% Input 
% X = data array 
% Output 
% X_filled = filled data array
% missing = M matrix with ones for nan values 

% filldata3 fills a 3-way array with the arithmetic mean of the other
% values in the array
    % fill as done for PCA with SVD (averages of each dimension)
    [i, j, k]=findnan3(X);% returns rows and columns with nan elements
    dim = size(X);
    missing = isnan(X); %linear indices 

    X_filled = X;
    % fill missing values with zeros 
    for ind = 1:length(i)
        X_filled(i(ind),j(ind), k(ind))=0;
    end 

    % find all means 
    mean1 = sum(X_filled,1)./(ones(1,dim(2),dim(3))*dim(1)-sum(missing,1)); % (1,j,k) dim1 
    mean2= sum(X_filled,2)./(ones(dim(1),1,dim(3))*dim(2)-sum(missing,2)); % (i,1,k)  dim2 
    mean3 = sum(X_filled,3)./(ones(dim(1),dim(2),1)*dim(3)-sum(missing,3));% (i,j,1) dim3 
    %replace nan means with 0 
    mean1(find(isnan(mean1)))=0;
    mean2(find(isnan(mean2)))=0;
    mean3(find(isnan(mean3)))=0; 
    for ind =1:length(i)
       % for all NaN elements that exist, loop through them to replace
        X_filled(i(ind),j(ind), k(ind))=(mean1(1,j(ind), k(ind))+mean2(i(ind),1, k(ind))+mean3(i(ind),j(ind),1))/3;
    end      
end 
function [i,j,k]=findfill3(X)
% Input 
% X = data array 
% Output 
% i, j, k = indexes of existing values in X

% findnan3 finds the nan indices of a 3-way array 
    dim3 = size(X,3);
    i=[];
    j=[];
    k=[];
    for d = 1:dim3
        % done per z slice 
        Xtemp = X(:,:,d);
        [itemp, jtemp]= find(~isnan(Xtemp));
        i = [i; itemp];
        j = [j;jtemp];
        ktemp = ones(length(itemp),1)*d;
        k = [k;ktemp];
    end 
end

function [i,j,k]=findnan3(X)
% Input 
% X = data array 
% Output 
% i, j, k = indexes of nan values in X

% isnan(X) returns logical array 
% all(isnan(X),1) is also a logical array (1x30x40) - each row
% find(all(isnan(X),1)) returns linear indices -> reshape array to correct
% dimension to find missing slabs 
% findnan3 finds the nan indices of a 3-way array 
    dim = size(X);
    dim1 = dim(1);
    dim2 = dim(2);
    dim3 = dim(3);

    i=[];
    j=[];
    k=[];
    for d = 1:dim3
        % done per z slice 
        Xtemp = X(:,:,d);
        [itemp, jtemp]= find(isnan(reshape(Xtemp,[dim1,dim2])));
        i = [i; itemp];
        j = [j;jtemp];
        ktemp = ones(length(itemp),1)*d;
        k = [k;ktemp];
    end 
end

function [SS]=sumsquare3(X,i,j,k)
% Input 
% X = data array 
% [i,j,k] indices of values of interest
% Output 
% SS = sum of the squares of the values of interest 
    tempX=[];
    for d = 1:length(i)
        tempX=[tempX;X(i(d),j(d),k(d))];
    end 
    SS = sum(tempX.^2);
end 
