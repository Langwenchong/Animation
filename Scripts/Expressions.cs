using System;
using System.Threading.Tasks;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System.IO;
using System.Text.RegularExpressions;

namespace Avatar
{
    //public class MyMesh
    //{
    //    public string name;
    //    public List<Vector3> vertices = new List<Vector3>();
    //    public List<int> triangles = new List<int>();
    //}

    public class Expressions : MonoBehaviour
    {
        // 获取游戏与音频组件对象
        private GameObject flame;
        private AudioSource audioSource;

        private bool talk = false;
        // 读取存储模型序列与音频的文件夹
        private string folderName1 = "meshes";
        private string folderName2 = "Audios";
        // 每个线程负责加载的mesh数量
        //private int batch_size = 200;
        // 固定刷新时间
        private float frameTime = 0.01666667f;
        // 用来更新模型网格的组件
        private MeshFilter meshFilter;
        // 需要记录一下静态人脸的模型
        private Mesh staticMesh;
        private List<Mesh> meshes;
        //private List<List<MyMesh>> myMeshes;
        private int currentFrame;
        private float timer;
        private string[] fileNames;

        // Start is called before the first frame update
        void Start()
        {
            // 注意人脸模型名称要求为Flame
            flame = GameObject.Find("Flame");
            audioSource = GameObject.Find("Audio").GetComponent<AudioSource>();
            meshFilter = flame.GetComponent<MeshFilter>();
            staticMesh = meshFilter.mesh;
        }

        // Update is called once per frame,Update()会导致音画不同步
        void FixedUpdate()
        {
            if (talk)
            {
                timer += Time.fixedDeltaTime;
                if (timer >= frameTime)
                {
                    audioSource.Pause();
                    timer = 0f;
                    meshFilter.mesh = meshes[currentFrame];
                    audioSource.Play();
                    currentFrame++;
                    if (currentFrame >= meshes.Count)
                    {
                        staticMesh = meshes[currentFrame - 1];
                        audioSource.Stop();
                        audioSource.clip = null;
                        talk = false;
                    }
                }
            }
            else
            {
                meshFilter.mesh = staticMesh;
            }
        }

        private void OnMouseDown()
        {
            print("click");
            Talk();
        }

        public void Talk()
        {
            if (!talk)
            {
                //myMeshes = new List<List<MyMesh>>();
                meshes = new List<Mesh>();
                currentFrame = 0;
                timer = 0f;

                // 获取Meshes文件夹下的模型文件并排序统计个数
                fileNames = Directory.GetFiles(Application.dataPath + "/" + folderName1, "*.obj");
                Array.Sort(fileNames, (a, b) => string.Compare(a, b));

                // 加载纹理的mesh:单线程，时间中等，但是会阻塞其他键鼠事件
                //TimeSpan _startTime = new TimeSpan(System.DateTime.Now.Ticks);
                //foreach (string fileName in fileNames)
                //{
                //    MyMesh myMesh = LoadOBJFile(fileName);
                //    Mesh mesh = new Mesh();
                //    mesh.name = myMesh.name;
                //    mesh.vertices = myMesh.vertices.ToArray();
                //    mesh.triangles = myMesh.triangles.ToArray();
                //    mesh.RecalculateNormals();
                //    meshes.Add(mesh);
                //}
                //TimeSpan _endTime = new TimeSpan(System.DateTime.Now.Ticks);
                //print("单线程运行时间差：" + _startTime.Subtract(_endTime).Duration().TotalMilliseconds.ToString());

                //// 加载有纹理的mesh:由于需要一个模型一个模型导入为mesh，所以多线程加速，时间时好时坏，但是不阻塞键鼠事件
                //List<Task> tasks = new List<Task>();
                //// todo: 有bug会失帧，这里先异步单线程
                //// 每batch_size个模型放一个线程里加载
                //print("meshes内部的文件数量" + fileNames.Length);
                //for (int i = 0; i + batch_size < fileNames.Length; i = i + batch_size)
                //{
                //    // 一定要是局部变量，否则会导致线程所有的赋值等待循环结束再开始任务分发错乱
                //    int stIdx = i;
                //    int edIdx = i + batch_size;
                //    // 创建线程
                //    tasks.Add(Task.Run(() => LoadOBJFileTask(stIdx, edIdx)));
                //}
                //// 最后一组可能凑不够batch_size也单开一个线程
                //int extra = fileNames.Length % batch_size;
                //if (extra != 0)
                //{
                //    tasks.Add(Task.Run(() => LoadOBJFileTask(fileNames.Length - extra, fileNames.Length)));
                //}
                //TimeSpan startTime = new TimeSpan(System.DateTime.Now.Ticks);
                //// 等待所有线程运行完毕
                //await Task.WhenAll(tasks.ToArray());
                //TimeSpan midTime = new TimeSpan(System.DateTime.Now.Ticks);
                //foreach (List<MyMesh> list in myMeshes)
                //{
                //    print(list.ToArray().Length);
                //    foreach (MyMesh myMesh in list)
                //    {
                //        Mesh mesh = new Mesh();
                //        mesh.name = myMesh.name;
                //        mesh.vertices = myMesh.vertices.ToArray();
                //        mesh.triangles = myMesh.triangles.ToArray();
                //        mesh.uv = myMesh.uv.ToArray();
                //        mesh.RecalculateNormals();
                //        meshes.Add(mesh);
                //    }
                //}
                //print(meshes.ToArray().Length);
                //meshes.Sort((a, b) => string.Compare(a.name, b.name));
                //foreach (Mesh mesh in meshes)
                //{
                //    print(mesh.name);
                //}
                //TimeSpan endTime = new TimeSpan(System.DateTime.Now.Ticks);
                //print("obj转MyMesh时间差：" + startTime.Subtract(midTime).Duration().TotalMilliseconds.ToString());
                //print("MyMesh转Mesh时间差：" + midTime.Subtract(endTime).Duration().TotalMilliseconds.ToString());

                // 加载有纹理的mesh(更快）:
                foreach (string fileName in fileNames)
                {
                    string relativePath = fileName.Replace(Application.dataPath, "Assets");
                    GameObject objParent = AssetDatabase.LoadAssetAtPath<GameObject>(relativePath);
                    if (objParent != null)
                    {
                        GameObject objChild = objParent.transform.Find("default").gameObject;
                        MeshFilter defaultMeshFilter = objChild.GetComponent<MeshFilter>();
                        Mesh defaultMesh = defaultMeshFilter.sharedMesh;
                        meshes.Add(defaultMesh);
                    }
                    else
                    {
                        print("objAsset not found");
                        break;
                    }
                }
                AudioClip clip = AssetDatabase.LoadAssetAtPath<AudioClip>("Assets/" + folderName2 + "/audio.wav");
                if (clip == null) print("not found audio");
                audioSource.clip = clip;
                EditorApplication.isPaused = true;
                talk = true;
                audioSource.Play();
                print("end");
            }
        }

        // 每一个要执行的某一部分的obj序列导入
        //public void LoadOBJFileTask(int start, int end)
        //{
        //    TimeSpan _startTime = new TimeSpan(System.DateTime.Now.Ticks);
        //    List<MyMesh> tmpList = new List<MyMesh>();
        //    int stIdx = start, edIdx = end;
        //    print("起始索引" + stIdx + "  结束索引" + edIdx);
        //    for (int j = stIdx; j < edIdx; j++)
        //    {
        //        // 加载模型
        //        MyMesh myMesh = LoadOBJFile(fileNames[j]);
        //        tmpList.Add(myMesh);
        //    }
        //    lock (myMeshes)
        //    {
        //        myMeshes.Add(tmpList);
        //    }
        //    TimeSpan _endTime = new TimeSpan(System.DateTime.Now.Ticks);
        //    print("线程运行时间差：" + _startTime.Subtract(_endTime).Duration().TotalMilliseconds.ToString());
        //}

        //MyMesh LoadOBJFile(string fileName)
        //{
        //    MyMesh myMesh = new MyMesh();
        //    StreamReader streamReader = new StreamReader(fileName);
        //    string objData = streamReader.ReadToEnd();
        //    streamReader.Close();

        //    List<Vector3> vertices = new List<Vector3>();
        //    List<int> triangles = new List<int>();
        //    List<Vector2> uvs = new List<Vector2>();
        //    List<Vector2> uv = new List<Vector2>();
        //    List<int> uvIndices = new List<int>();
        //    string[] lines = Regex.Split(objData, "\r\n");
        //    for (int i = 0; i < lines.Length; i++)
        //    {
        //        string line = lines[i];
        //        if (line.StartsWith("v "))
        //        {
        //            string[] parts = line.Split(new char[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
        //            float x = float.Parse(parts[1]);
        //            float y = float.Parse(parts[2]);
        //            float z = float.Parse(parts[3]);
        //            vertices.Add(new Vector3(x, y, z));
        //        }
        //        else if (line.StartsWith("f "))
        //        {
        //            // 提取三角形索引
        //            string[] parts = line.Split(new char[] { ' ' }, System.StringSplitOptions.RemoveEmptyEntries);
        //            for (int j = 0; j < 3; j++)
        //            {
        //                string[] subParts = parts[j + 1].Split('/');
        //                triangles.Add(int.Parse(subParts[0]) - 1);
        //            }
        //        }

        //    }
        //    myMesh.name = fileName;
        //    myMesh.vertices = vertices;
        //    myMesh.triangles = triangles;
        //    return myMesh;
        //}

    }
}

