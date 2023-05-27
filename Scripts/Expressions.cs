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
        // ��ȡ��Ϸ����Ƶ�������
        private GameObject flame;
        private AudioSource audioSource;

        private bool talk = false;
        // ��ȡ�洢ģ����������Ƶ���ļ���
        private string folderName1 = "meshes";
        private string folderName2 = "Audios";
        // ÿ���̸߳�����ص�mesh����
        //private int batch_size = 200;
        // �̶�ˢ��ʱ��
        private float frameTime = 0.01666667f;
        // ��������ģ����������
        private MeshFilter meshFilter;
        // ��Ҫ��¼һ�¾�̬������ģ��
        private Mesh staticMesh;
        private List<Mesh> meshes;
        //private List<List<MyMesh>> myMeshes;
        private int currentFrame;
        private float timer;
        private string[] fileNames;

        // Start is called before the first frame update
        void Start()
        {
            // ע������ģ������Ҫ��ΪFlame
            flame = GameObject.Find("Flame");
            audioSource = GameObject.Find("Audio").GetComponent<AudioSource>();
            meshFilter = flame.GetComponent<MeshFilter>();
            staticMesh = meshFilter.mesh;
        }

        // Update is called once per frame,Update()�ᵼ��������ͬ��
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

                // ��ȡMeshes�ļ����µ�ģ���ļ�������ͳ�Ƹ���
                fileNames = Directory.GetFiles(Application.dataPath + "/" + folderName1, "*.obj");
                Array.Sort(fileNames, (a, b) => string.Compare(a, b));

                // ���������mesh:���̣߳�ʱ���еȣ����ǻ��������������¼�
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
                //print("���߳�����ʱ��" + _startTime.Subtract(_endTime).Duration().TotalMilliseconds.ToString());

                //// �����������mesh:������Ҫһ��ģ��һ��ģ�͵���Ϊmesh�����Զ��̼߳��٣�ʱ��ʱ��ʱ�������ǲ����������¼�
                //List<Task> tasks = new List<Task>();
                //// todo: ��bug��ʧ֡���������첽���߳�
                //// ÿbatch_size��ģ�ͷ�һ���߳������
                //print("meshes�ڲ����ļ�����" + fileNames.Length);
                //for (int i = 0; i + batch_size < fileNames.Length; i = i + batch_size)
                //{
                //    // һ��Ҫ�Ǿֲ�����������ᵼ���߳����еĸ�ֵ�ȴ�ѭ�������ٿ�ʼ����ַ�����
                //    int stIdx = i;
                //    int edIdx = i + batch_size;
                //    // �����߳�
                //    tasks.Add(Task.Run(() => LoadOBJFileTask(stIdx, edIdx)));
                //}
                //// ���һ����ܴղ���batch_sizeҲ����һ���߳�
                //int extra = fileNames.Length % batch_size;
                //if (extra != 0)
                //{
                //    tasks.Add(Task.Run(() => LoadOBJFileTask(fileNames.Length - extra, fileNames.Length)));
                //}
                //TimeSpan startTime = new TimeSpan(System.DateTime.Now.Ticks);
                //// �ȴ������߳��������
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
                //print("objתMyMeshʱ��" + startTime.Subtract(midTime).Duration().TotalMilliseconds.ToString());
                //print("MyMeshתMeshʱ��" + midTime.Subtract(endTime).Duration().TotalMilliseconds.ToString());

                // �����������mesh(���죩:
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

        // ÿһ��Ҫִ�е�ĳһ���ֵ�obj���е���
        //public void LoadOBJFileTask(int start, int end)
        //{
        //    TimeSpan _startTime = new TimeSpan(System.DateTime.Now.Ticks);
        //    List<MyMesh> tmpList = new List<MyMesh>();
        //    int stIdx = start, edIdx = end;
        //    print("��ʼ����" + stIdx + "  ��������" + edIdx);
        //    for (int j = stIdx; j < edIdx; j++)
        //    {
        //        // ����ģ��
        //        MyMesh myMesh = LoadOBJFile(fileNames[j]);
        //        tmpList.Add(myMesh);
        //    }
        //    lock (myMeshes)
        //    {
        //        myMeshes.Add(tmpList);
        //    }
        //    TimeSpan _endTime = new TimeSpan(System.DateTime.Now.Ticks);
        //    print("�߳�����ʱ��" + _startTime.Subtract(_endTime).Duration().TotalMilliseconds.ToString());
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
        //            // ��ȡ����������
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

