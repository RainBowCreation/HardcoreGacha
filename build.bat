echo "Make sure spacetimedb is running 'spacetime start'."
cargo clean
cd shared
cd struct
cargo build
cargo run
cd ..
cd core
cargo build --release
cd ..
cd bindgen
wasm-pack build --target web --out-dir ../../client/ts/pkg
cd ../..
spacetime publish --project-path server hardcore-gacha
# spacetime generate --lang rust --out-dir client/rust/src/module_bindings --project-path server
spacetime generate --lang typescript --out-dir client/ts/src/module_bindings --project-path server
# spacetime generate --lang csharp --out-dir client/ch/module_bindings --project-path server

cd client/ts
del pkg/
cd src
del module_bindings/

Get-ChildItem -Path .\module_bindings -Recurse -File | ForEach-Object {
  $content = Get-Content -Raw -Path $_.FullName
  $pattern = 'import \{\s*AlgebraicType,\s*AlgebraicValue,\s*BinaryReader,\s*BinaryWriter,\s*CallReducerFlags,\s*ConnectionId,\s*DbConnectionBuilder,\s*DbConnectionImpl,\s*DbContext,\s*ErrorContextInterface,\s*Event,\s*EventContextInterface,\s*Identity,\s*ProductType,\s*ProductTypeElement,\s*ReducerEventContextInterface,\s*SubscriptionBuilderImpl,\s*SubscriptionEventContextInterface,\s*SumType,\s*SumTypeVariant,\s*TableCache,\s*TimeDuration,\s*Timestamp,\s*deepEqual,\s*\} from "@clockworklabs/spacetimedb-sdk";'
  $replace = @'
import {
  AlgebraicType,
  AlgebraicValue,
  BinaryReader,
  BinaryWriter,
  type CallReducerFlags,
  ConnectionId,
  DbConnectionBuilder,
  DbConnectionImpl,
  type DbContext,
  type ErrorContextInterface,
  type Event,
  type EventContextInterface,
  Identity,
  ProductType,
  ProductTypeElement,
  type ReducerEventContextInterface,
  SubscriptionBuilderImpl,
  type SubscriptionEventContextInterface,
  SumType,
  SumTypeVariant,
  TableCache,
  TimeDuration,
  Timestamp,
  deepEqual,
} from "@clockworklabs/spacetimedb-sdk";
'@
  $newContent = [regex]::Replace($content, $pattern, $replace)
  if ($newContent -ne $content) { Set-Content -Path $_.FullName -Value $newContent }
}

Get-ChildItem -Path .\module_bindings -Recurse -File | ForEach-Object {
  $content = Get-Content -Raw -Path $_.FullName
  $pattern = 'import { EventContext, Reducer, RemoteReducers, RemoteTables } from ".";'
  $replace = 'import { type EventContext, type Reducer, RemoteReducers, RemoteTables } from ".";'
  $newContent = [regex]::Replace($content, $pattern, $replace)
  if ($newContent -ne $content) { Set-Content -Path $_.FullName -Value $newContent }
}

echo "Done!"