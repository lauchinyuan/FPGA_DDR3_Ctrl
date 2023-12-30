%% 将4张图片写入连续地址空间, 作为DDR多通道读的测试数据
clc, clear;
%% 像素数据获取
% 图片名列表
file_name_array = ["zzu_640_480",  "szu_640_480", "cloud_640_480","fisherGirlStatue_640_480"];
txt_file_name = "fisherg"; %输出的多通道图的txt文件名
[void, file_num] = size(file_name_array); % file_num为图像文件数
% 将图片同一像素位置上的RGB值排在一起构成RGB888数据
for f = 1:file_num
    file_name = file_name_array(f); % 逐一获取列表中的文件名
    img = imread(fullfile("../img/",file_name+".jpg")); %读取原始文件
    if(f==1) % 第一张图像， 获取图像大小参数， 并开辟变量缓存空间
        [height, width, channel] = size(img);  % 获取图片大小参数
        imgrgb = zeros(file_num, height, width, channel);  %开辟空间
        imgrgb = imgrgb(:);  % 转换为1列
    end
    for h=1:height  % 获得Uint8格式的RGB单通道数据
        for w=1:width
            for c=1:channel
                imgrgb((f-1)*height*width*channel+(h-1)*width*channel+(w-1)*channel+c) = img(h, w, c);
            end
        end
    end
end

%% 数据处理与保存
% 将RGB数据组合成32bit数据, 方便存入硬件FIFO中
% R(8bit)+G(8bit)+B(8bit)+0(8bit)
rgb32b = zeros(file_num, height, width); % 开辟空间
rgb32b = rgb32b(:);  % 转换为1列
for f=1:file_num % 遍历文件
    for i=1:height*width % 遍历文件中像素
        r = imgrgb((f-1)*height*width*3+(i-1)*3+1);
        g = imgrgb((f-1)*height*width*3+(i-1)*3+2);
        b = imgrgb((f-1)*height*width*3+(i-1)*3+3);
        % 位拼接操作
        rgb32b((f-1)*height*width+i) = uint32(bitshift(r, 24) + bitshift(g, 16) + bitshift(b, 8));
    end
end

imgrgb = uint8(imgrgb);
rgb32b = uint32(rgb32b); % 转换为整数


% 32bit像素保存为txt文件,以二进制格式写入
txt_path = "../txt/"+txt_file_name+".txt"; % 文件路径
% 判断文件是否存在, 存在则删除
if exist(txt_path,'file')
    delete(txt_path);
end
fid = fopen(txt_path, "w");
fwrite(fid,rgb32b, "uint32","ieee-be");  % 输出至文件, 大端模式写入, 这样文件由高到低二进制顺序恰好为RGB0
fclose(fid);