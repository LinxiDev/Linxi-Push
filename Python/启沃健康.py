# 脚本活动: 故事答题(启沃健康)
# 活动地址: ✅今日学习入口：http://s.fex7g.cn/?t=RQZBy1zV

import os
import json
import requests
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed

# 脚本版本
version = "1.0.0"
name = "故事答题(启沃健康)"
lin_token = "jkgstoken"
lin_tips = '{"uid":"xxxxxxxx","sKey":"xxxxxxxx","ctId":"xxxxxx"}'
# 默认线程数
max_workers = 8
# 变量类型(本地/青龙)
Btype = "本地"
# 域名(无法使用时请更换)
domain = 'https://api.qingkeguanli.com/frontend/web/index.php?r=term-course'
# 缓存地址
turl = "http://linapi.serv00.net"
# 保持连接,重复利用
ss = requests.Session()
# 全局基础请求头
headers = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.39 (0x18002733) NetType/WIFI Language/zh_CN',
    'Content-Type': 'application/x-www-form-urlencoded'
}

def getid(uid):
    result = ss.get(f"{turl}/getdata?key={uid}").json()
    if result["code"] == 200:
        return result["data"]["value"]
    else:
        return False

def setid(uid,id):
    result = ss.put(f"{turl}/putdata",json={"key": uid,"value":id}).json()
    if result["code"] == 400:
        result = ss.post(f"{turl}/setdata",json={"key": uid,"value":id}).json()
        if result["code"] == 200:
            print(f"设置ID:{result['msg']}")
        else:
            print(f"设置ID:{result['msg']}")
    else:
        print(f"更新ID:{result['msg']}")

def scanid(ck):
    acid = int(getid(ck['uid']))
    if not acid:
        acid  = 0
    for actid in range(acid,99999):
        result = ss.get(f"{domain}/enter&userId={ck['uid']}&sessionKey={ck['sKey']}&courseId={actid}&consultantId={ck['ctId']}&corpId=", headers=headers).json()
        if result["code"] == 0:
            setid(ck['uid'],actid)
            return str(actid)

def get_user_info(i, ck):
    try:
        courseId = scanid(ck)
        result = ss.get(f"{domain}/enter&userId={ck['uid']}&sessionKey={ck['sKey']}&courseId={courseId}&consultantId={ck['ctId']}&corpId=", headers=headers).json()
        if result['code'] == 0:
            answer = [i['answer'] for i in result['data']['assignment']]
            answer = str(answer).replace("'", '"').replace(" ", "")
            print(f"账号【{i+1}】✅ 课程[{courseId}]: {result['data']['course_name']} 答案: {answer}")
            # memberId = result['data']['memberId']
            # progress = result['data']['duration']
            # result = ss.get(f"{domain}/progress&userId={ck['uid']}&sessionKey={ck['sKey']}&courseId={courseId}&memberId={memberId}&progress={progress}", headers=headers)
            result = ss.get(f"{domain}/finish&userId={ck['uid']}&sessionKey={ck['sKey']}&courseId={courseId}", headers=headers).json()
            if result['code'] == 0:
                print(f"账号【{i+1}】✅ 完成课程: {result['data']}")
            else:
                print(f"账号【{i+1}】❌ 完成课程: {result['msg']}")
            result = ss.get(f"{domain}/assignment&userId={ck['uid']}&sessionKey={ck['sKey']}&courseId={courseId}&consultantId={ck['ctId']}&answer={answer}", headers=headers).json()
            if result['code'] == 0:
                if 'consultantQrcode' in result['data']:
                    print(f"账号【{i+1}】⛔ 提交答案: 请加群主微信后重试!")
                elif result['data']['isCorrect'] == 1:
                    print(f"账号【{i+1}】❌ 提交答案: {result['data']['content']}")
                else:
                    print(f"账号【{i+1}】❌ 提交答案(未知问题)")
            else:
                if 'mpAppId' in result['msg']:
                    print(f"账号【{i+1}】✅ 提交答案: 答题成功！")
                else:
                    print(f"账号【{i+1}】❌ 提交答案: {result['msg']}")
        else:
            print(f"账号【{i+1}】❌ 课程[{courseId}]: {result['msg']}")
    except Exception as e:
        print(f"账号【{i+1}】⚠️ 获取用户信息失败: {e}")

def handle_exception(e, i):
    info = traceback.format_exc()
    print(f"账号【{i+1}】⚠️ 程序出现异常: {e} 详细信息:{info}")

if __name__ == "__main__":
    print(f"""██╗     ██╗███╗   ██╗           ██╗██╗  ██╗ ██████╗ ███████╗
██║     ██║████╗  ██║           ██║██║ ██╔╝██╔════╝ ██╔════╝
██║     ██║██╔██╗ ██║█████╗     ██║█████╔╝ ██║  ███╗███████╗
██║     ██║██║╚██╗██║╚════╝██   ██║██╔═██╗ ██║   ██║╚════██║
███████╗██║██║ ╚████║      ╚█████╔╝██║  ██╗╚██████╔╝███████║
╚══════╝╚═╝╚═╝  ╚═══╝       ╚════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    项目:{name}    BY-LinGPT   Verion: {version}(并发)
""")
    if Btype == "青龙":
        if os.getenv(lin_token) is None:
            print(f'⛔ 青龙变量异常: 请添加{lin_token}变量示例:{lin_tips} 确保一行一个')
            exit()
        ck_token = [json.loads(line) for line in os.getenv(lin_token).splitlines()]
    else:
        ck_token = [
            {"uid": "xxxx", "sKey": "xxxx", "ctId": "140"}
        ]
        if not ck_token:
            print(f'⛔ 本地变量异常: 请添加本地ck_token示例:{lin_tips}')
            exit()

    # 创建线程池
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for i, ck in enumerate(ck_token):
            futures.append(executor.submit(get_user_info, i, ck))

        print("================👻开始获取数据👻===============")
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                handle_exception(e, i)

        # 关闭连接
        ss.close()
        # 输出结果
        print(f"================[{name} V{version}]===============")