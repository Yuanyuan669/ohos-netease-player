export interface Song {
  id: number;
  name: string;
  author: string;
  cover: string;
  duration: number;
}

export interface Playlist {
  id: number;
  name: string;
  cover: string;
  trackCount: number;
  playCount: number;
}

// 下面是 music.163.com 公开接口的原始返回形状。字段随接口版本变化，
// 一律声明为可选，在 NeteaseApi 里归一化成上面的 Song / Playlist。
export interface RawArtist {
  name?: string;
}

export interface RawAlbum {
  name?: string;
  picUrl?: string;
}

export interface RawTrack {
  id?: number;
  name?: string;
  duration?: number;
  dt?: number;
  fee?: number;
  artists?: RawArtist[];
  album?: RawAlbum;
  ar?: RawArtist[];
  al?: RawAlbum;
}

export interface RawPlaylist {
  id?: number;
  name?: string;
  picUrl?: string;
  coverImgUrl?: string;
  trackCount?: number;
  trackNumber?: number;
  playCount?: number;
}

export interface RawTrackId {
  id?: number;
}

export interface RawDetail {
  id?: number;
  name?: string;
  picUrl?: string;
  coverImgUrl?: string;
  tracks?: RawTrack[];
  trackIds?: RawTrackId[];
}

export interface PersonalizedResponse {
  code?: number;
  result?: RawPlaylist[];
}

export interface TopListResponse {
  code?: number;
  list?: RawPlaylist[];
}

export interface DetailResponse {
  code?: number;
  result?: RawDetail;
  playlist?: RawDetail;
}

// fee: 0/8 免登录外链可播，1=VIP 4=付费专辑，外链 302 到 /404
export interface SongDetailResponse {
  code?: number;
  songs?: RawTrack[];
}
