% gf_mul_13 for Si
% GF(2^13)  elements from 1 to 128
%%
clear
clc
%%
gf_elements=[2 4 8 16 32 64 128 256 512 1024 2048 4096 27 54 108 216 432 864 1728 3456 6912 5659 3117 6234 4271 325 650 1300 2600 5200 2235 4470 759 1518 3036 6072 3947 7894 7607 7029 5873 3577 7154 6143 4069 8138 8079 7941 7697 7225 6249 4297 393 786 1572 3144 6288 4411 621 1242 2484 4968 1739 3478 6956 5699 3229 6458 4719 1221 2442 4884 1587 3174 6348 4483 797 1594 3188 6376 4555 909 1818 3636 7272 6347 4493 769 1538 3076 6152 4107 13 26 52 104 208 416 832 1664 3328 6656 5147 2093 4186 175 350 700 1400 2800 5600 3035 6070 3959 7918 7623 7061 5937 3705 7410 6655 5093 2001 4002 8004 7827 7485 6753 ];
% Verilog 代码中需要显示参数：
fprintf('**********************************************************************************************\n');
for i =1:128
   fprintf('parameter A_%d = 13^',i);
   fprintf('d%d;\n',gf_elements(i));
end
%%
%对于m=13，t=8的BCH译码，求伴随式时用到的（变量*常量）乘法器，优化过程
%S1
%变量输入data_a(矩阵为系数矩阵）
data_a = ones(1,13);
%常量输入A（16,13）每一行表示对应的Si所需要的(A^i)^8;此处为8位并行输入
%例如，S1计算过程，专用的乘法器是 13bits变量 乘于
%(A^1)^8=A^8=13'd256=13'b0000100000000,该值存在A
%中第一行中，低位在前，高位在后。下面程序为生成A矩阵
%声明A矩阵
A = zeros(16,13);
%读取GF(2^13)的元素,组成A矩阵
for i=1:16
    q=gf_elements(1,i*8);
    for j=1:13
        r=mod(q,2);
        q=fix(q / 2);
        A(i,j)=r;
    end
end
%%
%设输入变量B=b0 + b1*a +b2 *a^2 +b3 * a^3 +.....+b(m-1) * a^(m-1);(此处m=13)
%常量为Ai为A矩阵中的第i行；
%设C=B *Ai= m0 + m1*a +m2 *a^2 +m3 * a^3 +.....+m13 *a^13 +....m24 *a ^24;
%注：此时还没讲C对最小多项式m1(x)=x^13 + x^4 +x ^3 + x^1 +1 取模！！ 
%下面程序为生成mi的表达式（用mi表示）
fprintf('**********************************************************************************************\n');
 for i=1:16
    fprintf('for S%d:\n',i);
      for n = 1: 25
          fprintf('assign m[%d]=',n-1);
              for j = 1:13
                   for k =1:13
                         if k+j-2==n-1
                             if A(i,k)==1
                             fprintf('din_a[%d] ^ ',j-1);
                             end
                         end
                   end
             end
          fprintf(';\n');
      end
 end
%%
%下面对上面得到的C对% m1(x)=x^13 + x^4 +x ^3 + x^1 +1 取模即为最终输出结果。
%设结果为c0 +c1 *a^1 + c2 *a^2 + ...... +c12 *a^12;
%首先，计算F矩阵，设输入位宽为13，
M1=[0 0 0 0 0 0 0 0 1 1 0 1 1]';
r1=eye(12);
r2=zeros(1,12);
r3=[r1;r2];
R=[M1 r3];
F=R^13;
%对F矩阵每个元素都对2取模
F= mod(F,2);
% 由 c=(m0 + m1*a +m2 *a^2 +m3 * a^3 +.....+m13 *a^13 +....m24 *a^24)mod(a^13 + a^4 +a ^3 + a^1 +1)=(m13 *a^13 +....m24 *a^24)mod(a^13 + a^4 +a ^3 + a^1 +1) +(m0 + m1*a +m2 *a^2 +m3 * a^3 +.....+m12 *a^12)
% c=g[coeff] * M;  M=[m24 m23 ....m1 m0];g[coeff]系数高位在前，低位在后，如下
temp=eye(13);
for i=1:13
    for j=1:13
        if i==j
            temp(i,j)=0;
            temp(i,14-j)=1;
        end
    end
end
g = [F,temp];
%由于M只有25项，而g为13 * 26的系数矩阵，所以M前面需要补上一个零,也就是将g第一列去掉即可。
G = g(:,2:26);
%%
% 显示c的表达式
fprintf('**********************************************************************************************\n');
 fprintf('不优化表达式：\n');
for i=1:13
    fprintf('c[%d]=',13-i);
    for j=1:25
        if G(i,j)==1
            fprintf('m[%d] ^',25-j);
        end
    end
    fprintf(';\n');
end
%%
% 优化：寻找共享表达式
S_count=zeros(13,12); %用来显示共享表达式的次数
fprintf('**********************************************************************************************\n');
 fprintf('优化,寻找共享表达式：\n');
for k=1:13
      fprintf('c[%d] = ',13-k);
       for n=1:12
           for m=1:12
               if m>n   % 可以修改选择不同的共享表达式%  m>n+1
                   if G(k,n)==1 && G(k,m)==1 
                    fprintf('(m[%d] + m[%d]) ^ ',25-n,25-m);
                    G(k,n)=0;
                    G(k,m)=0;
                    S_count(n,m)= S_count(n,m) +1;
                   end
               end
           end
       end
  %显示没有共享的项
       for p=1:25
        if  G(k,p) == 1
            fprintf('m[%d] ^ ',25-p);
        end
       end
       fprintf(';\n');
end  
%显示共享次数
fprintf('**********************************************************************************************\n');
flag=0;
 fprintf('共享次数：\n');
 for m=1:3
  for i=1:13
     for j=1:12
         if S_count(i,j)==m
             if flag==0
             fprintf('共享 %d 次：(m[%d] + m[%d]) ',m,25-i,25-j);
             flag =1;
             else  fprintf(' (m[%d] + m[%d]) ',25-i,25-j);
             end
         end
     end
  end
   flag=0;
 fprintf('\n');
 end
%%
% 关于并行8位输入将7个乘法器优化成一个乘法器的分析
%%
% 
% <<gf_mul_1.png>>
% 
%%
% 
% <<gf_mul_2.png>>
% 
%%
% 生成 矩阵D（13,8,16） 其中13表示m值，8为并行度，16为伴随式数(对于每一列，高位在上，低位在下）
%从图片<<gf_mul_1.png>>可以得到D矩阵，下面是生成该矩阵过程

D = zeros(13,8,16);
%读取GF(2^13)的元素,组成D矩阵
for i=1:16
    % 第 8 列
      D(:,8,i)=[0 0 0 0 0 0 0 0 0 0 0 0 1]';
    % 第 2-8 列
    for j=1:7
        q=gf_elements(1,(8-j)*i);
        for k=1:13
             r=mod(q,2);
             q=fix(q / 2);
             D(14-k,j,i)=r;
        end
    end
end
%显示每个乘法器的结果表达
fprintf('**********************************************************************************************\n');
 fprintf('不优化表达式：\n');
  for i=1:16
    fprintf('for S%d:\n',i);
      for j = 1: 13
          fprintf('assign B_%d_1[%d] =',13-j);
              for k = 1:8
                    if D(j,k,i)==1
                         fprintf('din[%d] + ',8-k);
                    end
              end
               fprintf(';\n');
      end
  end
  %%
% 优化：寻找共享表达式
S_count_2=zeros(13,8,16); %用来显示共享表达式的次数
fprintf('**********************************************************************************************\n');
 fprintf('优化,寻找共享表达式：\n');
 for i=1:16 
     fprintf('//for S%d:\n',i);
   for k=1:13
      fprintf('assign B_%d_1[%d] = ',i,13-k);
       for n=1:8
           for m=1:8
               if m>n   % 可以修改选择不同的共享表达式%  m>n+1
                   if D(k,n,i)==1 && D(k,m,i)==1 
                    fprintf('(din[%d] + din[%d]) ^ ',8-n,8-m);
                    D(k,n,i)=0;
                    D(k,m,i)=0;
                    S_count_2(n,m,i)= S_count_2(n,m,i) +1;
                   end
               end
           end
       end
  %显示没有共享的项
       for p=1:8
        if  D(k,p,i) == 1
            fprintf('din[%d] ^ ',8-p);
        end
       end
       fprintf(';\n');
   end
   fprintf('assign C_%d = B_%d ^ B_%d_1;\n',i,i,i);
 end
%显示共享次数
fprintf('**********************************************************************************************\n');
%对每个Si的共享情况
flag=0;
 fprintf('共享次数：\n');
 for n=1:16 
     fprintf('for S%d:\n',n);
     for m=2:6 %次数
        for i=1:13
           for j=1:8
            if S_count_2(i,j,n)==m
             if flag==0
             fprintf('共享 %d 次：(din[%d] + din[%d]) ',m,8-i,8-j);
             flag =1;
             else  fprintf(' (din[%d] + din[%d]) ',8-i,8-j);
             end
         end
     end
   end
  if flag==1
   flag=0;
   fprintf('\n');
  end
     end
 end
 %%
 %整体共享情况 先对每个Si的S_count_2的值处理一下，也就是对应的位置叠加
 S_count_all = zeros(13,8);
     for j=1:13
         for k=1:8
              for i=1:16
                S_count_all(j,k) =S_count_all(j,k) + S_count_2(j,k,i);
              end
         end
     end
%显示S_count_all
S_count_all
%显示共享
        for i=1:13
           for j=1:8
            if S_count_all(i,j)>1
             fprintf('wire share_%d_%d ;\n',8-i,8-j); 
             fprintf('assign share_%d_%d = din[%d] ^ din[%d]; \n',8-i,8-j,8-i,8-j);
             end
         end
        end
%显示整体共享情况
flag=0;
 fprintf('整体共享次数：\n');
  for m=2:32 %次数
        for i=1:13
           for j=1:8
            if S_count_all(i,j)==m
             if flag==0
             fprintf('共享 %d 次：(din[%d] + din[%d]) ',m,8-i,8-j);
             flag =1;
             else  fprintf(' (din[%d] + din[%d]) ',8-i,8-j);
             end
         end
     end
   end
  if flag==1
   flag=0;
   fprintf('\n');
  end
  end
 %%
