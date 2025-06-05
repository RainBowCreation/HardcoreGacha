use neon::prelude::*;
use hg_shared::hash_sha256 as hash;

fn hash_sha256(mut cx: FunctionContext) -> JsResult<JsString> {
    let input = cx.argument::<JsString>(0)?.value(&mut cx);
    let result = hash(&input);
    Ok(cx.string(result))
}

#[neon::main]
fn main(mut cx: ModuleContext) -> NeonResult<()> {
    cx.export_function("hash_sha256", hash_sha256)?;
    Ok(())
}
