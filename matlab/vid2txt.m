%% 脚本说明:读取视频帧, 并将视频帧转换为txt文本形式的hex文本(R+G+B+0), 每一个像素点以32bit表示
%% 读取视频解析像素点文件
clc
clear all
file_name = "tvb";
txt_path = "../txt/"+file_name+"_uint32.txt"; % txt文件路径
num_frame = 192; % 读取的帧数, 注意不建议设置太大, 容易超出DDR容量限制
frame_h = 960; %帧高度， 若原始视频帧超出该高度, 将有截断舍去处理
frame_w = 1280; %帧宽度， 若原始视频帧超出该宽度, 将有截断舍去处理
obj_v = VideoReader(file_name+".mp4"); % 读取视频, 得到视频对象
frame = read(obj_v, [1 num_frame]); % 读取帧

imgrgb32 = zeros(num_frame*frame_h*frame_w, 1); %开辟空间
imgrgb32 = uint32(imgrgb32);
% 遍历帧像素数据并写入变量

% 同一个像素点的RGB数据放置在连续索引上
for f = 1:num_frame %帧遍历
    for h = 1: frame_h %行遍历
        for w = 1: frame_w % 行内像素点遍历 
            % 将RGB数据组合成32bit数据, 方便存入硬件FIFO中
            % R(8bit)+G(8bit)+B(8bit)+0(8bit)
            r = double(frame(h, w, 1, f));  % R数据
            g = double(frame(h, w, 2, f));  % G数据
            b = double(frame(h, w, 3, f));  % B数据
%             r = double(frame((f-1)*frame_h*frame_w*3+(h-1)*frame_w*3+(w-1)*3+1));% R数据
%             g = double(frame((f-1)*frame_h*frame_w*3+(h-1)*frame_w*3+(w-1)*3+2));% G数据
%             b = double(frame((f-1)*frame_h*frame_w*3+(h-1)*frame_w*3+(w-1)*3+3));% B数据
            %合成32bit数据并存到imgrgb变量中
            imgrgb32((f-1)*frame_h*frame_w+(h-1)*frame_w+w) = uint32(bitshift(r, 24) + bitshift(g, 16) + bitshift(b, 8));
        end
    end
end
%% 像素数据写入文
% 将32bit像素保存为txt文件, 实际上是以2进制形式编辑文件
fid = fopen(txt_path, "w"); %打开文件
fwrite(fid, imgrgb32, "uint32", "ieee-be");
fclose(fid);
