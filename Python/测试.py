# 脚本活动: 活动名称
# 活动地址: 活动地址

import os
import json
import time
import signal
import threading
import requests
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed

# 脚本版本
version = "1.0.0"
name = "活动名称"
lin_token = "demotoken"
lin_tips = '{"ck":"xxxxxxxx"}'
# 默认线程数
max_workers = 8
# 变量类型(本地/青龙)
Btype = "本地"
# 域名(无法使用时请更换)
domain = 'https://api.demo.com/api'
# 保持连接,重复利用
ss = requests.Session()
# 全局基础请求头
headers = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.39 (0x18002733) NetType/WIFI Language/zh_CN',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Origin': 'https://www.seniverse.com',
    'Referer': 'https://www.seniverse.com/',
}
# 全局日志容器（线程安全）
logs_by_account = {}
# 线程锁，防止多线程写冲突
log_lock = threading.Lock() 
# 信号处理器
def exit_gracefully(signum, frame):
    print("[强制结束] ⚠️ 正在强制终止所有线程...")
    os._exit(0) 
signal.signal(signal.SIGINT, exit_gracefully)
signal.signal(signal.SIGTERM, exit_gracefully)

def userinfo(i, ck):
    # 获取用户信息
    try:
        result = ss.get("https://widget-v3.seniverse.com/api/weather/4d55fc27-e045-4b12-a330-44b2d98f60ef?unit=c&language=zh-Hans&location=WX4FBXXFKE4F&geolocation=false&detected=zh-cn",headers=headers).json()
        log(i,f"账号【{i+1}】✅ 天气: {result['results'][0]['data'][0]['location']}")
        log(i,f"账号【{i+1}】✅ 用户信息")
    except Exception as e:
        log(i,f"账号【{i+1}】⚠️ 获取用户信息失败: {e}")

def exectask(i, ck):
    # 开始执行任务
    try:
        result = ss.get("https://widget-v3.seniverse.com/api/weather/4d55fc27-e045-4b12-a330-44b2d98f60ef?unit=c&language=zh-Hans&location=WX4FBXXFKE4F&geolocation=false&detected=zh-cn",headers=headers).json()
        log(i,f"账号【{i+1}】✅ 天气: {result['results'][0]['data'][0]['location']}")
        log(i,f"账号【{i+1}】✅ 开始执行任务")
    except Exception as e:
        log(i,f"账号【{i+1}】⚠️ 开始执行任务失败: {e}")

def withdrawal(i, ck):
    # 执行提现操作
    try:
        result = ss.get("https://widget-v3.seniverse.com/api/weather/4d55fc27-e045-4b12-a330-44b2d98f60ef?unit=c&language=zh-Hans&location=WX4FBXXFKE4F&geolocation=false&detected=zh-cn",headers=headers).json()
        log(i,f"账号【{i+1}】✅ 天气: {result['results'][0]['data'][0]['location']}")
        log(i,f"账号【{i+1}】✅ 执行提现操作")
        for i in range(10):
            result = ss.get("https://widget-v3.seniverse.com/api/weather/4d55fc27-e045-4b12-a330-44b2d98f60ef?unit=c&language=zh-Hans&location=WX4FBXXFKE4F&geolocation=false&detected=zh-cn",headers=headers).json()
            log(i,f"账号【{i+1}】✅ 天气: {result['results'][0]['data'][0]['location']}")
            log(i,f"账号【{i+1}】✅ 执行提现操作")
    except Exception as e:
        log(i,f"账号【{i+1}】⚠️ 执行提现操作失败: {e}")

def handle_exception(e, i):
    info = traceback.format_exc()
    print(f"账号【{i+1}】⚠️ 程序出现异常: {e} 详细信息:{info}")

def log(i, message):
    with log_lock:
        if i not in logs_by_account:
            logs_by_account[i] = []
        logs_by_account[i].append(message)

if __name__ == "__main__":
    start_time = time.time()
    print(f"""██╗     ██╗███╗   ██╗      ██████╗ ███████╗███╗   ███╗ ██████╗ 
██║     ██║████╗  ██║      ██╔══██╗██╔════╝████╗ ████║██╔═══██╗
██║     ██║██╔██╗ ██║█████╗██║  ██║█████╗  ██╔████╔██║██║   ██║
██║     ██║██║╚██╗██║╚════╝██║  ██║██╔══╝  ██║╚██╔╝██║██║   ██║
███████╗██║██║ ╚████║      ██████╔╝███████╗██║ ╚═╝ ██║╚██████╔╝
╚══════╝╚═╝╚═╝  ╚═══╝      ╚═════╝ ╚══════╝╚═╝     ╚═╝ ╚═════╝ 
    项目:{name}    BY-LinGPT   Verion: {version}(并发)
""")
    if Btype == "青龙":
        if os.getenv(lin_token) is None:
            print(f'⛔ 青龙变量异常: 请添加{lin_token}变量示例:{lin_tips} 确保一行一个')
            exit()
        ck_token = [json.loads(line) for line in os.getenv(lin_token).splitlines()]
    else:
        ck_token = [
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
            {"ck": "xxxx"},
        ]
        if not ck_token:
            print(f'⛔ 本地变量异常: 请添加本地ck_token示例:{lin_tips}')
            exit()

    # 创建线程池
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for i, ck in enumerate(ck_token):
            futures.append(executor.submit(userinfo, i, ck))
            futures.append(executor.submit(exectask, i, ck))
            futures.append(executor.submit(withdrawal, i, ck))

        
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                handle_exception(e, i)

    # 关闭连接
    ss.close()
    for i in sorted(logs_by_account.keys()):
        print(f"================👻账号[{i+1}]日志👻===============")
        for log in logs_by_account[i]:
            print(log)
    # 输出结果
    print(f"================[{name} V{version}]===============")
    end_time = time.time()
    print(f"总耗时：{end_time - start_time}秒")