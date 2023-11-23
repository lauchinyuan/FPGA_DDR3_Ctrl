clc, clear;
%% 像素数据获取
file_name = "fisherGirlStatue_1280_960";
img = imread(fullfile("../img/",file_name+".jpg")); %读取原始文件
[height, weight, channel] = size(img);  % 获取图片大小参数
% 将图片同一像素位置上的RGB值排在一起构成RGB888数据
imgrgb = zeros(size(img));  %开辟空间
imgrgb = imgrgb(:);  % 转换为1列
for h=1:height  % 获得Uint8格式的RGB单通道数据
    for w=1:weight
        for c=1:channel
            imgrgb((h-1)*weight*channel+(w-1)*channel+c) = img(h, w, c);
        end
    end
end
%imgrgb = uint8(imgrgb); %转换为Uint8格式

%% 数据处理与保存
% 将RGB数据组合成32bit数据, 方便存入硬件FIFO中
% R(8bit)+G(8bit)+B(8bit)+0(8bit)
rgb32b = zeros(height, weight); % 开辟空间
rgb32b = rgb32b(:);  % 转换为1列
for i=1:height*weight
    r = imgrgb((i-1)*3+1);
    g = imgrgb((i-1)*3+2);
    b = imgrgb((i-1)*3+3);
     % 位拼接操作
    rgb32b(i) = uint32(bitshift(r, 24) + bitshift(g, 16) + bitshift(b, 8));
end
imgrgb = uint8(imgrgb);
rgb32b = uint32(rgb32b); % 转换为整数

% % 三通道像素保存为txt文件
% txt_path = "../txt/"+file_name+".txt"; % 文件路径
% fid = fopen(txt_path, "w");
% fprintf(fid,"%02x",imgrgb);  % 输出至文件
% fclose(fid);

% 32bit像素保存为txt文件,以二进制格式写入
txt_path = "../txt/"+file_name+"_uint32.txt"; % 文件路径
fid = fopen(txt_path, "w");
fwrite(fid,rgb32b, "uint32","ieee-be");  % 输出至文件, 大端模式写入, 这样文件由高到低二进制顺序恰好为RGB0
fclose(fid);

