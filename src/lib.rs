use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

use infuse::{RenderItem, Renderer};
use instant;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;

const VERT: &str = include_str!("./shaders/vert.glsl");
const FRAG: &str = include_str!("./shaders/frag.glsl");

#[wasm_bindgen(start)]
pub fn start() -> Result<(), JsValue> {
    let mut renderer = Renderer::new()?;

    let start_time = instant::now();

    // add a shader that will use the uniform
    renderer.add_shader("colour".into(), VERT.into(), FRAG.into())?;

    // create the uniforms for the render item
    let mut uniforms = HashMap::new();
    uniforms.insert("time".to_string(), (start_time as f32, 0f32, 0f32, 0f32));

    let render_item = RenderItem::new(
        vec![
            -1.0, -1.0, 0.0, 1.0, -1.0, 0.0, 1.0, 1.0, 0.0, -1.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0,
            1.0, 0.0,
        ],
        "colour".into(),
        Some(uniforms),
    );

    let mut render_items = vec![render_item];

    let f = Rc::new(RefCell::new(None));
    let g = f.clone();

    *g.borrow_mut() = Some(Closure::wrap(Box::new(move || {
        let tick_time = instant::now();
        render_items[0].set_uniform(
            "time".to_string(),
            ((tick_time / 500f64) as f32, 0f32, 0f32, 0f32),
        );
        renderer.draw(&render_items).unwrap();

        request_animation_frame(f.borrow().as_ref().unwrap());
    }) as Box<dyn FnMut()>));

    request_animation_frame(g.borrow().as_ref().unwrap());

    Ok(())
}

fn request_animation_frame(f: &Closure<dyn FnMut()>) {
    web_sys::window()
        .expect("no global `window` exists")
        .request_animation_frame(f.as_ref().unchecked_ref())
        .expect("should register `requestAnimationFrame` OK");
}
