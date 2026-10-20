// The part viewer. Loaded only when someone opens a part, so three.js costs a visitor
// nothing until then.
import * as THREE from 'three';
import { STLLoader } from 'three/addons/STLLoader.js';
import { OrbitControls } from 'three/addons/OrbitControls.js';

const dialog = document.getElementById('viewer');
const canvas = dialog.querySelector('canvas');
const label = dialog.querySelector('h3');
const note = dialog.querySelector('.bar span');

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setClearColor(0x0f0f12, 1);

const scene = new THREE.Scene();
scene.add(new THREE.HemisphereLight(0xffffff, 0x27272a, 1.6));
const key = new THREE.DirectionalLight(0xffffff, 2.2);
key.position.set(1, -1.4, 2);
scene.add(key);

// OpenSCAD is Z-up, and so is this camera, so a part sits the way it prints.
const camera = new THREE.PerspectiveCamera(35, 1, 1, 5000);
camera.up.set(0, 0, 1);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.autoRotate = !matchMedia('(prefers-reduced-motion: reduce)').matches;
controls.autoRotateSpeed = 1.2;
controls.addEventListener('start', () => { controls.autoRotate = false; });

const material = new THREE.MeshStandardMaterial({ color: 0xd4d4d8, roughness: 0.6, metalness: 0.05 });
const edgeMaterial = new THREE.LineBasicMaterial({ color: 0xf59e0b, transparent: true, opacity: 0.35 });
const loader = new STLLoader();
let part = null;
let running = false;

function resize() {
  const { clientWidth: w, clientHeight: h } = canvas;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}

function frame() {
  if (!running) return;
  controls.update();
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

function clear() {
  if (!part) return;
  scene.remove(part);
  part.traverse((o) => o.geometry?.dispose());
  part = null;
}

export async function open(url, title) {
  label.textContent = title;
  note.textContent = 'Loading…';
  dialog.showModal();
  resize();
  running = true;
  frame();
  clear();
  try {
    const geometry = await loader.loadAsync(url);
    geometry.computeBoundingBox();
    const box = geometry.boundingBox;
    const centre = box.getCenter(new THREE.Vector3());
    geometry.translate(-centre.x, -centre.y, -centre.z);
    part = new THREE.Group();
    part.add(new THREE.Mesh(geometry, material));
    part.add(new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 30), edgeMaterial));
    scene.add(part);
    const size = box.getSize(new THREE.Vector3());
    const r = size.length() / 2;
    camera.position.set(r * 1.6, -r * 2.2, r * 1.3);
    controls.target.set(0, 0, 0);
    controls.autoRotate = !matchMedia('(prefers-reduced-motion: reduce)').matches;
    note.textContent = `${size.x.toFixed(1)} × ${size.y.toFixed(1)} × ${size.z.toFixed(1)} mm · drag to turn`;
  } catch {
    note.textContent = 'This part could not be loaded. The download still works.';
  }
}

dialog.addEventListener('close', () => { running = false; clear(); });
window.addEventListener('resize', () => { if (dialog.open) resize(); });
